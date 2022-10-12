defmodule CacheTest do
  @moduledoc """
  Module for integration testing of Cache API using registered genserver process.
  """
  use ExUnit.Case

  test "registers function" do
    assert :ok = Cache.register_function(fn -> {:ok, 42} end, "a", 1_000, 500)
  end

  test "gets value" do
    :ok = Cache.register_function(fn -> {:ok, 42} end, "test", 1_000, 500)
    # Let calculation propagate, so we don't need to wait 30 sec.
    Process.sleep(1)
    assert {:ok, 42} = Cache.get("test")
  end
end
