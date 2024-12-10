defmodule LoadGenerator.Application do
  @moduledoc false

  use Application

  @process_registry_name __MODULE__.Registry

  def name(id) do
    {:via, Registry, {@process_registry_name, id}}
  end

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, name: @process_registry_name, keys: :unique}
    ]

    opts = [strategy: :one_for_one, name: LoadGenerator.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
