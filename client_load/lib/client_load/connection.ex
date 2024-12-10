defmodule ClientLoad.Connection do
  use Task

  require Logger

  def child_spec(opts) do
    %{id: {__MODULE__, Keyword.fetch!(opts, :id)}, start: {__MODULE__, :start_link, [opts]}}
  end

  def start_link(args) do
    Task.start_link(__MODULE__, :run, [args])
  end

  def run(args) do
    aggregator = Keyword.get(args, :aggregator, ClientLoad.Aggregator)
    table = Keyword.fetch!(args, :table)
    client = Keyword.fetch!(args, :client)
    conn_id = Keyword.fetch!(args, :id)
    clients = Keyword.fetch!(args, :clients)
    interval = Keyword.get(args, :interval, 50)

    resume = ClientLoad.Aggregator.resume(ClientLoad.Aggregator)

    opts =
      if resume do
        Logger.info("resuming from #{inspect(resume)}")
        [resume: resume]
      else
        []
      end

    stream = Electric.Client.stream(client, table, opts)

    Process.sleep(Enum.random(1..(clients * interval)))

    ClientLoad.Aggregator.stream_start(aggregator, self(), clients)

    Enum.reduce(stream, {0, false}, fn msg, {c, up_to_date} ->
      case msg do
        %Electric.Client.Message.ChangeMessage{
          value: %{"id" => row_id, "inserted_at" => row_inserted_at},
          headers: %{operation: :insert, handle: handle},
          offset: offset,
          request_timestamp: request_timestamp
        } ->
          # ignore inserts that happened before the client made its request
          {:ok, inserted_at, 0} = DateTime.from_iso8601(row_inserted_at)

          ClientLoad.Aggregator.id_received(
            aggregator,
            row_id,
            handle,
            offset,
            conn_id,
            clients,
            inserted_after_request?(request_timestamp, inserted_at)
          )

          {c + 1, up_to_date}

        %Electric.Client.Message.ControlMessage{control: :up_to_date} ->
          {c, true}

        _ ->
          {c + 1, up_to_date}
      end
    end)
  end

  defp inserted_after_request?(request_timestamp, row_timestamp) do
    DateTime.compare(row_timestamp, request_timestamp) == :gt
  end
end
