defmodule Srh.Auth.TokenResolver do
  @mode Application.fetch_env!(:srh, :mode)
  @file_path Application.fetch_env!(:srh, :file_path)
  @file_hard_reload Application.fetch_env!(:srh, :file_hard_reload)

  @config_file_data nil

  def resolve(token) do
    IO.puts("Resolving token: #{token}")

    do_resolve(@mode, token)
  end

  defp do_resolve("file", token) do
    #    if @config_file_data == nil || @file_hard_reload do
    #      @config_file_data = Jason.decode!(File.read!(@file_path))
    #      IO.puts("Reloaded config file from disk. #{Jason.encode!(@config_file_data)}")
    #    end

    config_file_data = Jason.decode!(File.read!(@file_path))
    IO.puts("Reloaded config file from disk. #{Jason.encode!(config_file_data)}")

    case Map.get(config_file_data, token) do
      nil ->
        {:error, "Invalid token"}
      connection_info ->
        {:ok, connection_info}
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
