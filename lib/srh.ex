defmodule Srh do
  use Application

  @default_port Application.fetch_env!(:srh, :port)

  def start(_type, _args) do
    {port, ""} = Integer.parse(System.get_env("SRH_PORT", Integer.to_string(@default_port))) # Remains @default_port for backwards compatibility

    IO.puts("Using port #{port}")

    children = [
      Srh.Auth.TokenResolver,
      {GenRegistry, worker_module: Srh.Redis.Client},
      {
        Plug.Cowboy,
        scheme: :http,
        plug: Srh.Http.BaseRouter,
        options: [
          port: port
        ]
      }
    ]

    opts = [strategy: :one_for_one, name: Srh.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
