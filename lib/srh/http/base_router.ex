defmodule Srh.Http.BaseRouter do
  use Plug.Router
  alias Srh.Http.RequestValidator
  alias Srh.Http.CommandHandler

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason)
  plug(:dispatch)

  get "/" do
    handle_response({:ok, "Welcome to Serverless Redis HTTP!"}, conn)
  end

  post "/" do
    conn
    |> handle_extract_auth(&CommandHandler.handle_command(conn, &1))
    |> handle_response(conn)
  end

  post "/pipeline" do
    conn
    |> handle_extract_auth(&CommandHandler.handle_command_array(conn, &1))
    |> handle_response(conn)
  end

  post "/multi-exec" do
    conn
    |> handle_extract_auth(&CommandHandler.handle_command_transaction_array(conn, &1))
    |> handle_response(conn)
  end

  match _ do
    send_resp(conn, 404, "Endpoint not found")
  end

  defp handle_extract_auth(conn, success_lambda) do
    case conn
         |> get_req_header("authorization")
         |> RequestValidator.validate_bearer_header() do
      {:ok, token} ->
        success_lambda.(token)

      {:error, _} ->
        {:malformed_data, "Missing/Invalid authorization header"}
    end
  end

  defp handle_response(response, conn) do
    %{code: code, message: message, json: json} =
      case response do
        {:ok, data} ->
          %{code: 200, message: Jason.encode!(data), json: true}

        {:not_found, message} ->
          %{code: 404, message: message, json: false}

        {:malformed_data, message} ->
          %{code: 400, message: message, json: false}

        {:redis_error, data} ->
          %{code: 400, message: Jason.encode!(data), json: true}

        {:not_authorized, message} ->
          %{code: 401, message: message, json: false}

        {:server_error, _} ->
          %{code: 500, message: "An error occurred internally", json: false}

        _ ->
          %{code: 500, message: "An error occurred internally", json: false}
      end

    case json do
      true ->
        conn
        |> put_resp_header("content-type", "application/json")

      false ->
        conn
    end
    |> send_resp(code, message)
  end
end
