import Config

config :logger, level: :warning

config :client_load,
  clients: System.get_env("CLIENT_COUNT", "100") |> String.to_integer(),
  table: System.get_env("CLIENT_TABLE", "items"),
  interval: System.get_env("CLIENT_WAIT", "50") |> String.to_integer(),
  hosts:
    System.get_env("ELECTRIC_URL", "http://127.0.0.1:5555")
    |> :binary.split(",", [:global, :trim_all])
