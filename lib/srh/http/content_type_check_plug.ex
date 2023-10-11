defmodule Srh.Http.ContentTypeCheckPlug do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    # Only parse for POST, PUT, PATCH, and DELETE requests, which is what Plug.Parsers does
    case conn.method do
      "POST" ->
        check_content_type(conn)

      "PUT" ->
        check_content_type(conn)

      "PATCH" ->
        check_content_type(conn)

      "DELETE" ->
        check_content_type(conn)

      # All other methods can proceed
      _ ->
        conn
    end
  end

  defp check_content_type(conn) do
    case get_req_header(conn, "content-type") do
      ["application/json"] ->
        # Proceed, this is the valid content type for SRH
        conn

      # Either missing, or a type that we don't support
      _ ->
        # Return a custom error, ensuring the same format as the other errors
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          400,
          Jason.encode!(%{error: "Invalid content type. Expected application/json."})
        )
        |> halt()
    end
  end
end
