defmodule Srh.Redis.ClientWorker do
  use GenServer

  def start_link(connection_info) do
    GenServer.start_link(__MODULE__, connection_info, [])
  end

  def init(connection_info) do
    IO.puts("Client worker reporting for duty! Srh_id=#{Map.get(connection_info, "srh_id", "not found")}")

    Process.send(self(), :create_connection, [])

    {
      :ok,
      %{
        connection_info: connection_info,
        redix_pid: nil
      }
    }
  end

  def redis_command(worker, command_array) do
    GenServer.call(worker, {:redis_command, command_array})
  end

  def handle_call({:redis_command, command_array}, _from, %{redix_pid: redix_pid} = state)
      when is_pid(redix_pid) do
    case Redix.command(redix_pid, command_array) do
      {:ok, res} ->
        {:reply, {:ok, res}, state}

      {:error, res} ->
        {:reply, {:error, res}, state}
    end
  end

  def handle_call(msg, _from, state) do
    IO.inspect(msg)
    {:reply, :ok, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  # TODO: Handle host / port connections
  def handle_info(
        :create_connection,
        %{
          connection_info: %{
            "connection_string" => connection_string
          }
        } = state
      )
      when is_binary(connection_string) do
    {:ok, pid} = Redix.start_link(connection_string)
    IO.puts("Redis up and running for worker Srh_id=#{Map.get(state.connection_info, "srh_id", "not found")}")
    {:noreply, %{state | redix_pid: pid}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
