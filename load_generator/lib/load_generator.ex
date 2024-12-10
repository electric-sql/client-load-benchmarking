defmodule LoadGenerator do
  def row_stream(columns, format \\ :string) do
    LoadGenerator.Stream.new(columns, format)
  end

  def sleep(interval) do
    case interval do
      %Range{} = range -> Enum.random(range)
      n when is_integer(n) -> n
      fun when is_function(fun, 0) -> fun.()
    end
    |> Process.sleep()
  end
end
