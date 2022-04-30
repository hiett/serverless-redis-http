defmodule Srh.Http.CommandHandler do
  alias Srh.Http.RequestValidator
  alias Srh.Auth.TokenResolver
  alias Srh.Redis.Client
  alias Srh.Redis.ClientWorker

  def handle_command(conn, token) do
    case RequestValidator.validate_redis_body(conn.body_params) do
      {:ok, command_array} ->
        do_handle_command(command_array, token)
      {:error, error_message} ->
        {:malformed_data, error_message}
    end
  end

  def handle_command_array(conn, token) do
    case RequestValidator.validate_pipeline_redis_body(conn.body_params) do
      {:ok, array_of_command_arrays} ->
        do_handle_command_array(array_of_command_arrays, token)
      {:error, error_message} ->
        {:malformed_data, error_message}
    end
  end

  defp do_handle_command(command_array, token) do
    case TokenResolver.resolve(token) do
      {:ok, connection_info} ->
        dispatch_command(command_array, connection_info)
      {:error, msg} -> {:not_authorized, msg}
    end
  end

  defp do_handle_command_array(array_of_command_arrays, token) do
    case TokenResolver.resolve(token) do
      {:ok, connection_info} ->
        dispatch_command_array(array_of_command_arrays, connection_info)
      {:error, msg} -> {:not_authorized, msg}
    end
  end

  defp dispatch_command_array(_arr, _connection_info, responses \\ [])
  
  defp dispatch_command_array([current | rest], connection_info, responses) do
    updated_responses = case dispatch_command(current, connection_info) do
      {:ok, result_map} ->
        [result_map | responses]
      {:malformed_data, result_json} ->
        # TODO: change up the chain to json this at the last moment, so this isn't here
        [Jason.decode!(result_json) | responses]
    end

    dispatch_command_array(rest, connection_info, updated_responses)
  end

  defp dispatch_command_array([], _connection_info, responses) do
    # The responses will be in reverse order, as we're adding them to the list with the faster method of putting them at head.
    {:ok, Enum.reverse(responses)}
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
