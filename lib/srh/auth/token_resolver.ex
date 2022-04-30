defmodule Srh.Auth.TokenResolver do
  use GenServer

  @mode Application.fetch_env!(:srh, :mode)
  @file_path Application.fetch_env!(:srh, :file_path)
  @file_hard_reload Application.fetch_env!(:srh, :file_hard_reload)

  @ets_table_name :srh_token_resolver

  def start_link() do
    GenServer.start_link(__MODULE__, {}, [])
  end

  def child_spec(_opts) do
    %{
      id: :token_resolver,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end

  def init(_arg) do
    IO.puts("Token resolver started")

    # Create the ETS table
    table = :ets.new(@ets_table_name, [:named_table, read_concurrency: true])

    # Populate the ETS table with data from storage
    do_init_load(@mode)

    {
      :ok,
      %{
        table: table
      }
    }
  end

  def resolve(token) do
    do_resolve(@mode, token)
  end

  # Server methods
  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  # Internal server
  defp do_init_load("file") do
    config_file_data = Jason.decode!(File.read!(@file_path))
    IO.puts("Loaded config file from disk. #{map_size(config_file_data)} entries.")
    # Load this into ETS
    Enum.each(
      config_file_data,
      &(:ets.insert(@ets_table_name, &1))
    )
  end

  defp do_init_load(_), do: :ok

  # Internal, but client side, methods. These are client side to prevent GenServer lockup
  defp do_resolve("file", token) do
    #    if @hard_file_reload do
    #      do_init_load("file")
    #    end

    case :ets.lookup(@ets_table_name, token) do
      [{^token, connection_info}] -> {:ok, connection_info}
      [] -> {:error, "Invalid token"}
    end
  end

  defp do_resolve("redis", token) do
    {
      :ok,
      # This is done to replicate what will eventually be API endpoints, so they keys are not atoms
      Jason.decode!(
        Jason.encode!(
          %{
            srh_id: "1000",
            connection_string: "redis://localhost:6379",
            max_connections: 10
          }
        )
      )
    }
  end
end
