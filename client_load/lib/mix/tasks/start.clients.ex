defmodule Mix.Tasks.StartClients do
  use Mix.Task

  @shortdoc "Start client instances"

  def run(argv) do
    {opts, _, _} =
      OptionParser.parse(argv,
        strict: [clients: :integer, table: :string, host: [:string, :keep]]
      )

    clients = Keyword.get(opts, :clients, 100)
    table = Keyword.get(opts, :table, "items")
    hosts = Keyword.get_values(opts, :host) |> dbg

    Application.put_all_env([
      {:client_load, clients: clients, table: table, hosts: hosts},
      {:logger, level: :info}
    ])

    Application.ensure_all_started(:client_load)
    Process.sleep(:infinity)
  end
end
