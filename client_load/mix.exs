defmodule ClientLoad.MixProject do
  use Mix.Project

  def project do
    [
      app: :client_load,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ClientLoad.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:electric_client, path: "./electric-client/"},
      {:electric_client,
       github: "electric-sql/electric",
       branch: "client-request-pool-behaviour",
       subdir: "packages/elixir-client",
       depth: 1},
      {:dotenvy, "~> 0.8"},
      {:postgrex, "~> 0.19"},
      {:postgresql_uri, "~> 0.1.0"}
    ]
  end
end
