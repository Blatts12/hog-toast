defmodule HogToastTest do
  use ExUnit.Case

  doctest HogToast

  test "greets the world" do
    assert HogToast.hello() == :world
  end
end
