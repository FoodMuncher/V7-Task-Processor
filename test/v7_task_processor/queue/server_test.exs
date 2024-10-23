defmodule V7TaskProcessor.Queue.ServerTest do
  use ExUnit.Case

  alias V7TaskProcessor.Queue.Server

  test "Simple start up test" do
    start_supervised!(Server)
    assert Process.alive?(Process.whereis(Server))
  end
end
