defmodule Srh.Redis.Client do
  use GenServer
  alias Srh.Redis.ClientRegistry
  alias Srh.Redis.ClientWorker

  @idle_death_time 1000 * 15

  def start_link(max_connections, connection_info) do
    GenServer.start_link(__MODULE__, {max_connections, connection_info}, [])
  end

  def init({max_connections, connection_info}) do
    IO.puts("Client starting alive! Srh_id=#{Map.get(connection_info, "srh_id", "not found")}")

    Process.send(self(), :create_registry, [])

    {
      :ok,
      %{
        registry_pid: nil,
        idle_death_ref: nil,
        max_connections: max_connections,
        connection_info: connection_info
      }
    }
  end

  def find_worker(client)  do
    GenServer.call(client, {:find_worker})
  end

  def handle_call({:find_worker}, _from, %{registry_pid: registry_pid} = state)
      when is_pid(registry_pid) do
    {:ok, worker} = ClientRegistry.find_worker(registry_pid)
    Process.send(self(), :reset_idle_death, [])
    {:reply, worker, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def handle_info(:idle_death, state) do
    IO.puts("Client dying! No requests for period. Srh_id=#{Map.get(state.connection_info, "srh_id", "not found")}")
    ClientRegistry.destroy_workers(state.registry_pid)

    {:stop, :normal, state}
  end

  def handle_info(:reset_idle_death, state) do
    if state.idle_death_ref != nil do
      Process.cancel_timer(state.idle_death_ref)
    end

    {
      :noreply,
      %{state | idle_death_ref: Process.send_after(self(), :idle_death, @idle_death_time)}
    }
  end

  def handle_info(:create_registry, state) do
    {:ok, pid} = ClientRegistry.start_link()

    # Spin up three workers
    for _ <- 1..Map.get(state.connection_info, "max_connections", 3) do
      {:ok, worker} = ClientWorker.start_link(state.connection_info)
      ClientRegistry.add_worker(pid, worker)
    end

    {:noreply, %{state | registry_pid: pid}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
