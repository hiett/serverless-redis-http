defmodule Srh.Http.SubscribeHandler do
  alias Srh.Auth.TokenResolver
  alias Srh.Redis.PubSubWorker
  alias Srh.Http.SseHelper

  @heartbeat_interval 15_000

  # On success, the connection has already been switched into SSE/chunked mode and
  # fully streamed (the function only returns once the client disconnects), so the
  # caller just needs to hand the resulting conn back to Plug as-is.
  def handle_subscribe(conn, channel, token) do
    handle_stream(conn, token, &PubSubWorker.subscribe(&1, channel))
  end

  def handle_psubscribe(conn, pattern, token) do
    handle_stream(conn, token, &PubSubWorker.psubscribe(&1, pattern))
  end

  defp handle_stream(conn, token, subscribe_lambda) do
    case TokenResolver.resolve(token) do
      {:ok, connection_info} ->
        do_handle_stream(conn, connection_info, subscribe_lambda)

      {:error, msg} ->
        {:not_authorized, msg}
    end
  end

  defp do_handle_stream(conn, connection_info, subscribe_lambda) do
    case PubSubWorker.start_link(connection_info) do
      {:ok, pubsub_pid} ->
        {:ok, _ref} = subscribe_lambda.(pubsub_pid)

        streamed_conn =
          conn
          |> SseHelper.start_stream()
          |> stream_loop(pubsub_pid)

        {:stream, streamed_conn}

      {:error, _reason} ->
        {:connection_error, "SRH: Unable to connect to the Redis server for pub/sub."}
    end
  end

  # Blocks, forwarding every pub/sub message down the SSE stream, until either the
  # subscribed-to Redis connection or the client's HTTP connection goes away. Handles
  # both plain channel subscriptions and pattern (P)SUBSCRIBE ones, since they arrive
  # on the same kind of connection and only differ in message shape.
  defp stream_loop(conn, pubsub_pid) do
    receive do
      {:redix_pubsub, ^pubsub_pid, _ref, :subscribed, %{channel: channel}} ->
        # The @upstash/redis client requires 3 comma-separated fields here
        # (type,channel,count) even though it discards the channel for this event
        # type - a 2-field "subscribe,1" is silently dropped by its parser. Each
        # /subscribe connection only ever subscribes to a single channel, so the
        # count is always 1.
        forward_event(conn, pubsub_pid, "subscribe,#{channel},1")

      {:redix_pubsub, ^pubsub_pid, _ref, :psubscribed, %{pattern: pattern}} ->
        forward_event(conn, pubsub_pid, "psubscribe,#{pattern},1")

      {:redix_pubsub, ^pubsub_pid, _ref, :message, %{channel: channel, payload: payload}} ->
        forward_event(conn, pubsub_pid, "message,#{channel},#{payload}")

      {:redix_pubsub, ^pubsub_pid, _ref, :pmessage,
       %{pattern: pattern, channel: channel, payload: payload}} ->
        forward_event(conn, pubsub_pid, "pmessage,#{pattern},#{channel},#{payload}")

      # :disconnected / :unsubscribed and anything else: nothing to forward to the
      # client, Redix.PubSub will keep retrying the Redis connection on its own.
      {:redix_pubsub, ^pubsub_pid, _ref, _other_kind, _props} ->
        stream_loop(conn, pubsub_pid)
    after
      # Nothing came from Redis for a while. Without this, a client that disconnects
      # during a silent channel would never be noticed (and the pub/sub connection
      # would leak) until/unless a real message eventually arrived.
      @heartbeat_interval ->
        forward_heartbeat(conn, pubsub_pid)
    end
  end

  defp forward_event(conn, pubsub_pid, event) do
    case SseHelper.send_event(conn, event) do
      {:ok, conn} ->
        stream_loop(conn, pubsub_pid)

      {:error, _reason} ->
        # The client disconnected mid-stream, tear down the Redis side too.
        PubSubWorker.stop(pubsub_pid)
        conn
    end
  end

  defp forward_heartbeat(conn, pubsub_pid) do
    case SseHelper.send_comment(conn, "heartbeat") do
      {:ok, conn} ->
        stream_loop(conn, pubsub_pid)

      {:error, _reason} ->
        PubSubWorker.stop(pubsub_pid)
        conn
    end
  end
end
