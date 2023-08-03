defmodule Srh.Http.BaseRouter do
  use Plug.Router
  alias Srh.Http.RequestValidator
  alias Srh.Http.CommandHandler
  alias Srh.Http.ResultEncoder

  plug(:match)
  plug(Srh.Http.ContentTypeCheckPlug)
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
    handle_response({:not_found, "SRH: Endpoint not found. SRH might not support this feature yet."}, conn)
  end

  defp do_command_request(conn, success_lambda) do
    encoding_enabled = handle_extract_encoding?(conn)

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

  defp handle_extract_encoding?(conn) do
    case conn
         |> get_req_header("upstash-encoding")
         |> RequestValidator.validate_encoding_header() do
      {:ok, _encoding_enabled} -> true
      # it's not required to be present
      {:error, _} -> false
    end
  end

  defp handle_encoding_step(response, encoding_enabled) do
    case encoding_enabled do
      true ->
        # We need to use the encoder to
        ResultEncoder.encode_response(response)

      false ->
        response
    end
  end

  defp handle_response(response, conn) do
    # Errors are strings, and data just means the content is directly encoded with Jason.encode!
    # {404, {:error, "Message"}}
    # {200, {:data, ""}}

    {code, resp_data} =
      case response do
        {:ok, data} ->
          {200, {:data, data}}

        {:not_found, message} ->
          {404, {:error, message}}

        {:malformed_data, message} ->
          {400, {:error, message}}

        {:redis_error, data} ->
          {400, {:data, data}}

        {:not_authorized, message} ->
          {401, {:error, message}}

        {:connection_error, message} ->
          {500, {:error, message}}

        _ ->
          {500, {:error, "An error occurred internally"}}
      end

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(code, create_response_body(resp_data))
  end

  # :data just directly encodes
  defp create_response_body({:data, data}), do: Jason.encode!(data)

  # :error wraps the message in an error object
  defp create_response_body({:error, error}), do: Jason.encode!(%{error: error})
end
