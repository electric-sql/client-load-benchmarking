defmodule ClientLoad.ConnectionSupervisor do
  use Supervisor

  require Logger

  def start_link(config) do
    Supervisor.start_link(__MODULE__, config, name: __MODULE__)
  end

  def init(config) do
    {:ok, hosts} = Keyword.fetch(config, :hosts)
    {:ok, client_count} = Keyword.fetch(config, :clients)

    Logger.info("Starting #{client_count} client connections")
    Logger.info("Endpoints: \n\n#{Enum.map_join(hosts, "\n", &"- #{&1}")}\n")

    clients =
      Enum.map(hosts, fn host ->
        {:ok, client} = ClientLoad.client(host)
        client
      end)

    client_stream = Stream.cycle(clients)

    connections =
      Enum.zip(1..client_count, client_stream)
      |> Enum.map(fn {id, client} ->
        {ClientLoad.Connection, Keyword.merge(config, id: id, client: client)}
      end)

    Supervisor.init(connections,
      strategy: :one_for_one,
      max_restarts: client_count
    )
  end
end
