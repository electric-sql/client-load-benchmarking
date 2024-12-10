defmodule ClientLoad.Aggregator do
  use GenServer

  require Logger

  def start_link(n) do
    GenServer.start_link(__MODULE__, n, name: __MODULE__)
  end

  def wait(pids) do
    receive do
      {:DOWN, _ref, :process, pid, reason} ->
        dbg(down: {pid, reason})
        wait(pids)
    end
  end

  def stream_start(aggregator, conn, total) do
    live = :ets.update_counter(__MODULE__, :stream, 1, {:stream, 0})

    if rem(live, 10) == 0, do: log_count(live, total)

    GenServer.cast(aggregator, {:stream_start, conn})
  end

  def id_received(pid, id, handle, offset, time \\ DateTime.utc_now(), _client, total, usable?) do
    count =
      :ets.update_counter(__MODULE__, id, {2, 1}, {id, 0, System.monotonic_time(:millisecond)})

    if usable? do
      if count == 1 do
        id_started(pid, id, handle, offset, 1, time)
      else
        if :rand.normal() |> abs() < 0.0001 do
          id_started(pid, id, handle, offset, count, time)
        end
      end
    end

    if count >= total do
      [{^id, _count, start_time}] = :ets.lookup(__MODULE__, id)
      id_complete(pid, id, System.monotonic_time(:millisecond) - start_time)
    end
  end

  def id_complete(pid, id, milliseconds) do
    GenServer.cast(pid, {:id_complete, id, milliseconds, NaiveDateTime.utc_now()})
  end

  def id_started(pid, id, handle, offset, count, time) do
    GenServer.cast(pid, {:id_started, id, handle, offset, count, time})
  end

  def resume(pid) do
    # long timeout to prevent cascading failures when things are flaky
    GenServer.call(pid, :resume, :infinity)
  end

  def init(n) do
    table = :ets.new(__MODULE__, [:named_table, :public, :set, write_concurrency: :auto])
    region = System.get_env("FLY_REGION", "---")
    machine_id = System.get_env("FLY_MACHINE_ID", "---")
    Logger.info("Running in region #{inspect(region)}")

    conn =
      case System.get_env("DATABASE_URL", nil) do
        e when e in ["", nil] ->
          nil

        database_url ->
          params = PostgresqlUri.parse(database_url)
          {:ok, conn} = Postgrex.start_link(params)
          Logger.info("Connected to stats db #{database_url}")

          {:ok, query} =
            Postgrex.prepare(
              conn,
              "item_stat_insert",
              "INSERT INTO item_stats (item_id, n, region, machine_id, received_at) VALUES ($1, $2, '#{region}', '#{machine_id}', $3)"
            )

          {conn, query}
      end

    {:ok, %{table: table, n: n, conn: conn, offset: nil, handle: nil}}
  end

  def handle_call(:resume, _from, state) do
    resume =
      if state.offset && state.handle do
        %Electric.Client.Message.ResumeMessage{
          shape_handle: state.handle,
          offset: state.offset,
          schema: nil
        }
      end

    {:reply, resume, state}
  end

  def handle_cast({:stream_start, pid}, state) do
    Process.monitor(pid)
    {:noreply, state}
  end

  def handle_cast({:id_started, id, handle, offset, count, now}, %{conn: {conn, query}} = state) do
    if count == 1,
      do:
        IO.inspect(
          [start: [id: id, offset: offset, time: now]],
          pretty: false,
          width: :infinity
        )

    case Postgrex.execute(conn, query, [id, count, now]) do
      {:ok, _query, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to insert metrics: #{inspect(reason)}")
    end

    {:noreply, %{state | offset: offset, handle: handle}}
  end

  def handle_cast({:id_started, _id, _now}, state) do
    {:noreply, state}
  end

  def handle_cast({:id_complete, id, milliseconds, now}, state) do
    IO.inspect(
      [complete: [id: id, count: state.n, duration: milliseconds, time: now]],
      pretty: false,
      width: :infinity
    )

    :ets.delete(state.table, id)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    live = :ets.update_counter(__MODULE__, :stream, -1, {:stream, 0})

    log_count(live, state.n, "[draining] ")

    {:noreply, state}
  end

  defp log_count(live, total, prefix \\ "") do
    n = total |> to_string() |> byte_size()

    IO.write([
      prefix,
      "#{String.pad_leading(to_string(live), n, " ")}/#{total} #{floor(100 * live / total)}%\n"
    ])
  end
end
