defmodule ChatExampleElixirTest do
  use ExUnit.Case
  doctest ChatExampleElixir

  test "greets the world" do
    assert ChatExampleElixir.hello() == :world
  end
end
