defmodule Srh.Http.BaseRouter do
  use Plug.Router
  alias Srh.Http.RequestValidator
  alias Srh.Http.CommandHandler

  plug :match
  plug Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason
  plug :dispatch

  get "/" do
    handle_response({:ok, "Welcome to Serverless Redis HTTP!"}, conn)
  end

  post "/" do
    case conn
         |> get_req_header("authorization")
         |> RequestValidator.validate_bearer_header()
      do
      {:ok, token} ->
        CommandHandler.handle_command(conn, token)
      {:error, _} ->
        {:malformed_data, "Missing/Invalid authorization header"}
    end
    |> handle_response(conn)
  end

  match _ do
    send_resp(conn, 404, "Endpoint not found")
  end

  defp handle_response(response, conn) do
    %{code: code, message: message} =
      case response do
        {:ok, data} -> %{code: 200, message: Jason.encode!(data)}
        {:not_found, message} -> %{code: 404, message: message}
        {:malformed_data, message} -> %{code: 400, message: message}
        {:server_error, _} -> %{code: 500, message: "An error occurred internally"}
      end

    conn
    |> send_resp(code, message)
  end
end
