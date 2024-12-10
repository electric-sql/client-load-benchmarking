import Config

Dotenvy.source!([System.get_env()])

config :logger, level: :info

if config_env() == :prod do
  config :client_load,
    clients: Dotenvy.env!("CLIENT_COUNT", :integer, 100),
    table: Dotenvy.env!("CLIENT_TABLE", :string, "items"),
    interval: Dotenvy.env!("CLIENT_WAIT", :integer, 50),
    hosts:
      Dotenvy.env!("ELECTRIC_URL", :string, "http://127.0.0.1:5555")
      |> :binary.split(",", [:global, :trim_all])
end
