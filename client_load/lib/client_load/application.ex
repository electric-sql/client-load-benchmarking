defmodule ClientLoad.Application do
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    config = Application.get_all_env(:client_load)

    {:ok, client_count} = Keyword.fetch(config, :clients)

    children = [{ClientLoad.Aggregator, client_count}, {ClientLoad.ConnectionSupervisor, config}]

    opts = [strategy: :rest_for_one, name: ClientLoad.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
