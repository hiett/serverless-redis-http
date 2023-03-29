defmodule Srh.Http.BaseRouter do
  use Plug.Router
  alias Srh.Http.RequestValidator
  alias Srh.Http.CommandHandler
  alias Srh.Http.ResultEncoder

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason)
  plug(:dispatch)

  get "/" do
    handle_response({:ok, "Welcome to Serverless Redis HTTP!"}, conn)
  end

  post "/" do
    do_command_request(conn, &CommandHandler.handle_command(&1, &2))
  end

  post "/pipeline" do
    do_command_request(conn, &CommandHandler.handle_command_array(&1, &2))
  end

  post "/multi-exec" do
    do_command_request(conn, &CommandHandler.handle_command_transaction_array(&1, &2))
  end

  match _ do
    send_resp(conn, 404, "Endpoint not found")
  end

  defp do_command_request(conn, success_lambda) do
    encoding_enabled = handle_extract_encoding(conn)

    conn
    |> handle_extract_auth(&success_lambda.(conn, &1))
    |> handle_encoding_step(encoding_enabled)
    |> handle_response(conn)
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

  defp handle_extract_encoding(conn) do
    case conn
         |> get_req_header("upstash-encoding")
         |> RequestValidator.validate_encoding_header() do
      {:ok, _encoding_enabled} -> true
      {:error, _} -> false # it's not required to be present
    end
  end

  defp handle_encoding_step(response, encoding_enabled) do
    case encoding_enabled do
      true ->
        # We need to use the encoder to
        ResultEncoder.encode_response(response)
      false -> response
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
