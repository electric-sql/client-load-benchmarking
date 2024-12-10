defmodule ClientLoadTest do
  use ExUnit.Case
  doctest ClientLoad

  test "greets the world" do
    assert ClientLoad.hello() == :world
  end
end
