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
        last_worker_index: 0,
        currently_borrowed_pids: []
      }
    }
  end

  def find_worker(registry) do
    GenServer.call(registry, {:find_worker})
  end

  def borrow_worker(registry) do
    GenServer.call(registry, {:borrow_worker})
  end

  def return_worker(registry, pid) do
    GenServer.cast(registry, {:return_worker, pid})
  end

  def add_worker(registry, pid) do
    GenServer.cast(registry, {:add_worker, pid})
  end

  def destroy_workers(registry) do
    GenServer.cast(registry, {:destroy_workers})
  end

  def handle_call({:borrow_worker}, _from, state) do
    case do_find_worker(state) do
      {{:error, msg}, state_update} ->
        {:reply, {:error, msg}, state_update}

      {{:ok, pid}, state_update} ->
        # We want to put this pid into the borrowed pids state list
        {
          :reply,
          {:ok, pid},
          %{
            state_update
          |
            currently_borrowed_pids:
              [pid | state_update.currently_borrowed_pids]
              |> Enum.uniq()
          }
        }
    end
  end

  def handle_call({:find_worker}, _from, state) do
    {res, state_update} = do_find_worker(state)
    {:reply, res, state_update}
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
      |
        worker_pids:
          [pid | state.worker_pids]
          |> Enum.uniq()
      }
    }
  end

  def handle_cast({:destroy_workers}, state) do
    for worker_pid <- state.worker_pids do
      Srh.Redis.ClientWorker.destroy_redis(worker_pid)
    end

    {:noreply, %{state | worker_pids: [], last_worker_index: 0}}
  end

  def handle_cast({:return_worker, pid}, state) do
    # Remove it from the borrowed array
    {
      :noreply,
      %{state | currently_borrowed_pids: List.delete(state.currently_borrowed_pids, pid)}
    }
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

  defp do_find_worker(state) do
    filtered_pids =
      state.worker_pids
      |> Enum.filter(&(!Enum.member?(state.currently_borrowed_pids, &1)))

    case length(filtered_pids) do
      0 ->
        {{:error, :none_available}, state}

      len ->
        target = state.last_worker_index + 1

        corrected_target =
          case target >= len do
            true -> 0
            false -> target
          end

        {
          {:ok, Enum.at(state.worker_pids, corrected_target)},
          %{state | last_worker_index: corrected_target}
        }
    end
  end
end
