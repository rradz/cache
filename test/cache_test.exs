defmodule CacheTest do
  use ExUnit.Case
  doctest Cache

  defmodule DummyFunctions do
    def success, do: {:ok, 42}

    def success_with_delay do
      Process.sleep(1_000)

      {:ok, 42}
    end

    def failure, do: {:error, "Universe is malfunctioning"}
  end

  describe "registration" do
    setup do
      start_supervised(Cache)

      :ok
    end

    test "correctly registers the function" do
      assert :ok = Cache.register_function(&DummyFunctions.success/0, "success", 10_000, 1_000)
      assert :ok = Cache.register_function(&DummyFunctions.success/0, "success_2", 10_000, 1_000)
      assert :ok = Cache.register_function(&DummyFunctions.failure/0, "failure", 10_000, 1_000)
    end

    test "doesn't allow registering under the same key twice" do
      assert :ok = Cache.register_function(&DummyFunctions.success/0, "success", 10_000, 1_000)

      assert {:error, :already_registered} =
               Cache.register_function(&DummyFunctions.success/0, "success", 10_000, 1_000)
    end
  end

  describe "retrieval" do
    setup do
      start_supervised(Cache)

      :ok = Cache.register_function(&DummyFunctions.success/0, "success", 10_000, 1_000)

      :ok =
        Cache.register_function(
          &DummyFunctions.success_with_delay/0,
          "success_with_delay",
          10_000,
          1_000
        )

      :ok = Cache.register_function(&DummyFunctions.failure/0, "failure", 10_000, 1_000)

      :ok
    end

    test "returns the value of the registered function" do
      assert {:ok, 42} = Cache.get("success")
    end

    test "returns error when function is not registered" do
      assert {:error, :not_registered} = Cache.get("unregistered")
    end

    test "gives the last value when function is recomputed" do
      assert false
    end

    test "waits for timeout when result unavailable" do
      assert false
    end

    test "results in error if timeout is reached" do
      assert false
    end
  end
end
