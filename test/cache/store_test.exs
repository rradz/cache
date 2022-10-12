defmodule Cache.StoreTest do
  use ExUnit.Case, async: true

  describe "Store" do
    setup do
      {:ok, store} = Cache.Store.start_link([])

      {:ok, store: store}
    end

    test "can store value", %{store: store} do
      assert :ok = Cache.Store.store(store, "a", 1, 1_000)
    end

    test "can retrieve value", %{store: store} do
      :ok = Cache.Store.store(store, "a", 1, 1_000)

      assert {:ok, 1} = Cache.Store.get(store, "a")
    end

    test "removes expired values", %{store: store} do
      :ok = Cache.Store.store(store, "a", 1, 50)
      Process.sleep(100)

      assert :no_value = Cache.Store.get(store, "a")
    end

    test "doesn't remove values which were updated before expire time", %{store: store} do
      :ok = Cache.Store.store(store, "a", 1, 50)
      # Timestamp we use is in milliseconds and we need to ensure it changes
      Process.sleep(2)
      :ok = Cache.Store.store(store, "a", 2, 10_000)
      Process.sleep(100)

      assert {:ok, 2} = Cache.Store.get(store, "a")
    end
  end
end
