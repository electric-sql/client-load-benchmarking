defmodule ClientLoad do
  def client(url) do
    Electric.Client.new(
      base_url: url,
      pool: {ClientLoad.Mint, []},
      fetch: {ClientLoad.Mint, []}
    )
  end
end
