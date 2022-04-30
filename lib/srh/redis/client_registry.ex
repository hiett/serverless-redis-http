defmodule Srh.Redis.ClientRegistry do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, %{}, [])
  end

  def init(_opts) do
    {
      :ok,
      %{
        worker_pids: [],
        last_worker_index: 0
      }
    }
  end

  def find_worker(registry) do
    GenServer.call(registry, {:find_worker})
  end

  def add_worker(registry, pid) do
    GenServer.cast(registry, {:add_worker, pid})
  end

  def destroy_workers(registry) do
    GenServer.cast(registry, {:destroy_workers})
  end

  def handle_call({:find_worker}, _from, state) do
    case length(state.worker_pids) do
      0 ->
        {:reply, {:error, :none_available}, state}

      len ->
        target = state.last_worker_index + 1

        corrected_target =
          case target >= len do
            true -> 0
            false -> target
          end

        {:reply, {:ok, Enum.at(state.worker_pids, corrected_target)},
         %{state | last_worker_index: corrected_target}}
    end
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast({:add_worker, pid}, state) do
    Process.monitor(pid)

    {
      :noreply,
      %{
        state
        | worker_pids:
            [pid | state.worker_pids]
            |> Enum.uniq()
      }
    }
  end

  def handle_cast({:destroy_workers}, state) do
    for worker_pid <- state.worker_pids do
      Process.exit(worker_pid, :normal)
    end

    {:noreply, %{state | worker_pids: [], last_worker_index: 0}}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, pid, :normal, _ref}, state) do
    {:noreply, %{state | worker_pids: List.delete(state.worker_pids, pid)}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
