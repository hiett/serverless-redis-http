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

  def handle_command_transaction_array(conn, token) do
    # Transactions use the same body format as pipelines, so we can use the same validator
    case RequestValidator.validate_pipeline_redis_body(conn.body_params) do
      {:ok, array_of_command_arrays} ->
        do_handle_command_transaction_array(array_of_command_arrays, token)

      {:error, error_message} ->
        {:malformed_data, error_message}
    end
  end

  defp do_handle_command(command_array, token) do
    case TokenResolver.resolve(token) do
      {:ok, connection_info} ->
        dispatch_command(command_array, connection_info)

      {:error, msg} ->
        {:not_authorized, msg}
    end
  end

  defp do_handle_command_array(array_of_command_arrays, token) do
    case TokenResolver.resolve(token) do
      {:ok, connection_info} ->
        dispatch_command_array(array_of_command_arrays, connection_info)

      {:error, msg} ->
        {:not_authorized, msg}
    end
  end

  defp do_handle_command_transaction_array(array_of_command_arrays, token) do
    case TokenResolver.resolve(token) do
      {:ok, connection_info} ->
        dispatch_command_transaction_array(array_of_command_arrays, connection_info)

      {:error, msg} ->
        {:not_authorized, msg}
    end
  end

  defp dispatch_command_array(_arr, _connection_info, responses \\ [])

  defp dispatch_command_array([current | rest], connection_info, responses) do
    updated_responses =
      case dispatch_command(current, connection_info) do
        {:ok, result_map} ->
          [result_map | responses]

        {:redis_error, result} ->
          [result | responses]
      end

    dispatch_command_array(rest, connection_info, updated_responses)
  end

  defp dispatch_command_array([], _connection_info, responses) do
    # The responses will be in reverse order, as we're adding them to the list with the faster method of putting them at head.
    {:ok, Enum.reverse(responses)}
  end

  defp dispatch_command_transaction_array(
         command_array,
         %{"srh_id" => srh_id, "max_connections" => max_connections} = connection_info,
         responses \\ []
       ) do
    case GenRegistry.lookup_or_start(Client, srh_id, [max_connections, connection_info]) do
      {:ok, client_pid} ->
        # Borrow a client, then run all of the commands (wrapped in MULTI and EXEC)
        worker_pid = Client.borrow_worker(client_pid)

        # We are manually going to invoke the MULTI, because there might be a connection error to the Redis server.
        # In that case, we don't want the error to be wound up in the array of errors,
        # we instead want to return the error immediately.
        case ClientWorker.redis_command(worker_pid, ["MULTI"]) do
          {:ok, _} ->
            do_dispatch_command_transaction_array(command_array, worker_pid, responses)

            # Now manually run the EXEC - this is what contains the information to form the response, not the above
            result =
              case ClientWorker.redis_command(worker_pid, ["EXEC"]) do
                {:ok, res} ->
                  {
                    :ok,
                    res
                    |> Enum.map(&%{result: &1})
                  }

                {:error, error} ->
                  decode_error(error)
              end

            Client.return_worker(client_pid, worker_pid)

            # Fire back the result here, because the initial Multi was successful
            result

          {:error, error} ->
            decode_error(error)
        end

      {:error, msg} ->
        {:server_error, msg}
    end
  end

  defp do_dispatch_command_transaction_array([current | rest], worker_pid, responses)
       when is_pid(worker_pid) do
    updated_responses =
      case ClientWorker.redis_command(worker_pid, current) do
        {:ok, res} ->
          [%{result: res} | responses]

        {:error, error} ->
          [
            %{
              error: error.message
            }
            | responses
          ]
      end

    do_dispatch_command_transaction_array(rest, worker_pid, updated_responses)
  end

  defp do_dispatch_command_transaction_array([], worker_pid, responses) when is_pid(worker_pid) do
    {:ok, Enum.reverse(responses)}
  end

  defp dispatch_command(
         command_array,
         %{"srh_id" => srh_id, "max_connections" => max_connections} = connection_info
       )
       when is_number(max_connections) do
    case GenRegistry.lookup_or_start(Client, srh_id, [max_connections, connection_info]) do
      {:ok, pid} ->
        # Run the command
        case Client.find_worker(pid)
             |> ClientWorker.redis_command(command_array) do
          {:ok, res} ->
            {:ok, %{result: res}}

          {:error, error} ->
            decode_error(error)
        end

      {:error, msg} ->
        {:server_error, msg}
    end
  end

  # Figure out if it's an actual Redis error or a Redix error
  defp decode_error(error) do
    case error do
      %{reason: :closed} ->
        {
          :connection_error,
          "Unable to connect to the Redis server"
        }

      _ ->
        {
          :redis_error,
          %{
            error: error.message
          }
        }
    end
  end
end
