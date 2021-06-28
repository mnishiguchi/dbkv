defmodule DubDBTest do
  use ExUnit.Case
  doctest DubDB

  test "greets the world" do
    assert DubDB.hello() == :world
  end
end
