defmodule Srh.Redis.ClientWorker do
  use GenServer

  def start_link(connection_info) do
    GenServer.start_link(__MODULE__, connection_info, [])
  end

  def init(connection_info) do
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
    IO.puts("redis_command (for pid #{inspect(worker)}): #{inspect(command_array)}")
    GenServer.call(worker, {:redis_command, command_array})
  end

  def destroy_redis(worker) do
    GenServer.cast(worker, {:destroy_redis})
  end

  def handle_call({:redis_command, command_array}, _from, %{redix_pid: redix_pid} = state)
      when is_pid(redix_pid) do
    case Redix.command(redix_pid, command_array) do
      {:ok, res} ->
        {:reply, {:ok, res}, state}

      # Both connection errors and Redis command errors will be handled here
      {:error, res} ->
        {:reply, {:error, res}, state}
    end
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast({:destroy_redis}, %{redix_pid: redix_pid} = state) when is_pid(redix_pid) do
    # Destroy the redis instance & ensure cleanup
    Redix.stop(redix_pid)
    Process.exit(redix_pid, :normal)

    {:stop, :normal, %{state | redix_pid: nil}}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def handle_info(
        :create_connection,
        %{
          connection_info: %{
            "connection_string" => connection_string
          }
        } = state
      )
      when is_binary(connection_string) do
    # NOTE: Redix only seems to open the connection when the first command is sent
    # This means that this will return :ok even if the connection string may not actually be connectable
    {:ok, pid} = Redix.start_link(connection_string)
    {:noreply, %{state | redix_pid: pid}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
