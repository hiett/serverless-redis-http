defmodule Srh.Auth.TokenResolver do
  use GenServer

  @file_path Application.fetch_env!(:srh, :file_path)

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
    do_init_load(get_token_loader_mode())

    {
      :ok,
      %{
        table: table
      }
    }
  end

  def resolve(token) do
    do_resolve(get_token_loader_mode(), token)
  end

  # Server methods
  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  # Internal server
  defp get_token_loader_mode() do
    System.get_env("SRH_MODE", "file")
  end

  defp do_init_load("file") do
    config_file_data = Jason.decode!(File.read!(@file_path))
    IO.puts("Loaded config file from disk. #{map_size(config_file_data)} entries.")
    # Load this into ETS
    Enum.each(
      config_file_data,
      &:ets.insert(@ets_table_name, &1)
    )
  end

  defp do_init_load("env") do
    srh_token = System.get_env("SRH_TOKEN")
    srh_connection_string = System.get_env("SRH_CONNECTION_STRING")

    # Returns an error if fails, first tuple value is the number
    {srh_max_connections, ""} = Integer.parse(System.get_env("SRH_MAX_CONNECTIONS", "3"))

    # Create a config-file-like structure that the ETS layout expects, with just one entry
    config_file_data =
      Map.put(%{}, srh_token, %{
        # Jason.parse! expects these keys to be strings, not atoms, so we need to replicate that setup
        "srh_id" => "env_config_connection",
        "connection_string" => srh_connection_string,
        "max_connections" => srh_max_connections
      })

    IO.puts("Loaded config from env. #{map_size(config_file_data)} entries.")
    # Load this into ETS
    Enum.each(config_file_data, &:ets.insert(@ets_table_name, &1))
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

  # The env strategy uses the same ETS table as the file strategy, so we can fall back on that
  defp do_resolve("env", token), do: do_resolve("file", token)

  #  defp do_resolve("redis", _token) do
  #    {
  #      :ok,
  #      # This is done to replicate what will eventually be API endpoints, so they keys are not atoms
  #      Jason.decode!(
  #        Jason.encode!(%{
  #          srh_id: "1000",
  #          connection_string: "redis://localhost:6379",
  #          max_connections: 10
  #        })
  #      )
  #    }
  #  end
end
