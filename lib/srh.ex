defmodule Srh do
  use Application

  def start(_type, _args) do
    children = [
      {GenRegistry, worker_module: Srh.Redis.Client},
      {
        Plug.Cowboy,
        scheme: :http,
        plug: Srh.Http.BaseRouter,
        options: [
          port: 8080
        ]
      }
    ]

    opts = [strategy: :one_for_one, name: Srh.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
