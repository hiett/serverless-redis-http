defmodule Srh.Redis.PubSubWorker do
  alias Srh.Redis.ConnectionOpts

  # Unlike Srh.Redis.ClientWorker, pub/sub connections are not pooled: each subscribed
  # HTTP connection gets its own dedicated Redix.PubSub connection, kept open for as
  # long as that HTTP connection stays open.
  def start_link(%{"connection_string" => connection_string}) do
    Redix.PubSub.start_link(connection_string, ConnectionOpts.build(connection_string))
  end

  # Subscribes the calling process to a single channel. Redix.PubSub then sends
  # `{:redix_pubsub, pubsub_pid, ref, :subscribed | :message, payload}` messages
  # directly to this process' mailbox.
  def subscribe(pubsub_pid, channel) do
    Redix.PubSub.subscribe(pubsub_pid, channel, self())
  end

  # Same as subscribe/2, but for glob-style patterns (PSUBSCRIBE). Redix.PubSub sends
  # `:psubscribed` / `:pmessage` messages instead.
  def psubscribe(pubsub_pid, pattern) do
    Redix.PubSub.psubscribe(pubsub_pid, pattern, self())
  end

  def stop(pubsub_pid) do
    Redix.PubSub.stop(pubsub_pid)
  end
end
