defmodule Mix.Tasks.Gen.Load do
  use Mix.Task

  @shortdoc "Generate Load"
  @doc """
  ## mix gen.load

  - Table should exist and schema should match the column spec.

  ### Arguments

  - `table` - the table name in the database.
  - `db` - URI of the database, defaults to: `postgresql://postgres:password@localhost:5432/electric`
  - `column` - column generator specification. Can be given multiple times
  - `tps` - how many transactions per second to generate (default `1`)
  - `reset` - delete existing data from `table` before generating new data.
  - `duration` - how long to run for (in seconds)

  ## Columns

  Columns are specified as `name[:type[:size]]`.

  If not specified, `type` defaults to `text` and `size` to `10..128` bytes.

  `type` can be `text`, `integer` or `uuid`.

  `size` can be a fixed number of bytes, e.g. `123` or a range, e.g. `1..1000`.
  If given as a range, the generated size will be picked randomly from that
  range.

  For `text` columns, the size specifies the number of bytes in the value, for
  `integer` types, the size defines the value of the column.

  For `uuid` types, the size is ignored.

  ## Examples


      mix gen.load --table "items" --db "$DATABASE_URL" --column "id:uuid" --column "value:text:128" --tps 10
      # -c is equivalent to --column
      mix gen.load --table "items" --db "$DATABASE_URL" -c "id:uuid" -c "value:text:128" --tps 10

  """
  def run(argv) do
    {:ok, _apps} = Application.ensure_all_started(:load_generator)

    {opts, _, _} =
      OptionParser.parse(argv,
        strict: [
          db: :string,
          table: :string,
          # examples:
          #   id:uuid
          #   name (-> name:string:10..128)
          #   name:string (-> name:string:10..128)
          #   name:string:0..1024
          #   count:integer:3
          column: [:string, :keep],
          reset: :boolean,
          duration: :integer,
          tps: :integer
        ],
        aliases: [c: :column, p: :partition]
      )

    db_uri = Keyword.get(opts, :db, "postgresql://postgres:password@localhost:5432/electric")
    table = Keyword.fetch!(opts, :table)
    column_specs = Keyword.get_values(opts, :column)
    columns = Enum.map(column_specs, &LoadGenerator.Column.parse_spec!/1)
    reset = Keyword.get(opts, :reset, false)

    duration =
      case Keyword.get(opts, :duration, :infinity) do
        seconds when is_integer(seconds) -> seconds * 1000
        :infinity -> :infinity
      end

    tps = Keyword.get(opts, :tps, 1)

    batch_size = 5

    threads = ceil(tps / batch_size)

    stream = LoadGenerator.row_stream(columns, :binary)

    if reset do
      IO.puts(IO.ANSI.format([:red, "Deleting all data in #{table}\n"]))
      LoadGenerator.DB.reset!(table)
    end

    {:ok, db} = LoadGenerator.DB.start_link(db_uri, threads)

    {:ok, collector} =
      Task.start_link(fn ->
        receive_tx(0, System.monotonic_time(:millisecond), duration)
      end)

    Enum.reduce(1..threads, tps, fn p, remaining_tps ->
      tps = min(remaining_tps, batch_size)

      Task.start_link(fn ->
        start = System.monotonic_time(:millisecond)

        Enum.reduce(stream, 0, fn row, n ->
          now = System.monotonic_time(:millisecond)
          age = (now - start) / 1000
          expected_inserts = round(age * tps)
          diff = expected_inserts - n

          if diff > 0 do
            n = n + 1
            LoadGenerator.DB.insert!(table, row, db)

            value = inspect(row)

            send(
              collector,
              {:txn, p, n, [binary_part(value, 0, min(byte_size(value), 32)), "..."],
               byte_size(value)}
            )

            n
          else
            Process.sleep(1)
            n
          end
        end)
      end)

      remaining_tps - tps
    end)

    Process.sleep(duration)
  end

  defp receive_tx(n, start, duration) do
    receive do
      {:txn, _p, _n, value, size} ->
        now = System.monotonic_time(:millisecond)
        n = n + 1

        remaining =
          case duration do
            duration when is_integer(duration) ->
              remaining = (duration - (now - start)) / 1000 / 60
              mins = floor(remaining)
              seconds = round((remaining - mins) * 60)
              "remaining #{mins}m #{seconds}s"

            :infinity ->
              ""
          end

        IO.puts([
          "#{n} #{remaining} #{Float.round(n / ((now - start) / 1000), 2)}tps - ",
          value,
          " ",
          to_string(size),
          "b"
        ])

        receive_tx(n, start, duration)
    end
  end
end
