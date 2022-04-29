defmodule Srh.MixProject do
  use Mix.Project

  def project do
    [
      app: :srh,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      config_path: "config/config.exs",
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Srh, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:redix, "~> 1.1"},
      {:castore, ">= 0.0.0"},
      {:plug, "~> 1.13"},
      {:cowboy, "~> 2.9"},
      {:plug_cowboy, "~> 2.5"},
      {:jason, "~> 1.3"},
      {:gen_registry, "~> 1.1"}
    ]
  end
end
