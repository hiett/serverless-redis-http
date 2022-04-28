defmodule Srh.Http.CommandHandler do
  alias Srh.Http.RequestValidator
  alias Srh.Auth.TokenResolver
  alias Srh.Redis.Client
  alias Srh.Redis.ClientWorker

  def handle_command(conn, token) do
    case RequestValidator.validate_redis_body(conn.body_params) do
      {:ok, command_array} ->
        IO.inspect(command_array)
        do_handle_command(command_array, token)
      {:error, error_message} ->
        {:malformed_data, error_message}
    end
  end

  defp do_handle_command(command_array, token) do
    case TokenResolver.resolve(token) do
      {:ok, connection_info} ->
        dispatch_command(command_array, connection_info)
      {:error, _} -> {:error, "Invalid token"}
    end
  end

  defp dispatch_command(command_array, %{"srh_id" => srh_id, "max_connections" => max_connections} = connection_info)
       when is_number(max_connections) do
    case GenRegistry.lookup_or_start(Client, srh_id, [max_connections, connection_info]) do
      {:ok, pid} ->
        # Run the command
        case Client.find_worker(pid)
             |> ClientWorker.redis_command(command_array) do
          {:ok, res} ->
            {:ok, %{result: res}}
          {:error, error} ->
            {
              :malformed_data,
              Jason.encode!(
                %{
                  error: error.message
                }
              )
            }
        end
      {:error, msg} ->
        {:server_error, msg}
    end
  end
end
