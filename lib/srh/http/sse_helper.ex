defmodule Srh.Http.SseHelper do
  import Plug.Conn

  @sse_headers [
    {"content-type", "text/event-stream"},
    {"cache-control", "no-cache"},
    {"connection", "keep-alive"}
  ]

  # Sets the headers required for SSE, and switches the connection into chunked mode.
  # After this, the connection is ready for send_event/2 to be called as many times as needed.
  def start_stream(conn) do
    conn
    |> merge_resp_headers(@sse_headers)
    |> send_chunked(200)
  end

  # Sends a single "data: ..." SSE event down an already-started chunked connection.
  # Returns the same {:ok, conn} / {:error, reason} tuple as Plug.Conn.chunk/2, since the
  # client may have disconnected mid-stream.
  def send_event(conn, data) when is_binary(data) do
    chunk(conn, "data: #{data}\n\n")
  end

  # Sends an SSE comment line (starts with ":" instead of "data:"). Per the SSE spec,
  # compliant parsers ignore these outright, which makes them a safe no-op payload for
  # heartbeats: writing one is only a way to trigger a write attempt (and so notice a
  # dead connection promptly) during otherwise-silent streams.
  def send_comment(conn, comment) when is_binary(comment) do
    chunk(conn, ": #{comment}\n\n")
  end
end
