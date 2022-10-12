defmodule Cache.ServerTest do
  use ExUnit.Case, async: true

  # Necessary for testing for changing values
  defmodule DummyGenServer do
    use GenServer

    def get() do
      GenServer.call(__MODULE__, :get)
    end

    def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

    def init(_), do: {:ok, 0}

    def handle_call(:get, _from, state) do
      if state > 0, do: Process.sleep(60_000)
      {:reply, {:ok, state}, state + 1}
    end
  end

  defmodule DummyFunctions do
    def success, do: {:ok, 42}

    def success_with_delay do
      Process.sleep(1_000)

      {:ok, 42}
    end

    def failure, do: {:error, "Universe is malfunctioning"}

    def changing, do: DummyGenServer.get()
  end

  describe "registration" do
    setup do
      {:ok, server} = start_supervised(Cache.Server)

      {:ok, server: server}
    end

    test "registers the function", %{server: server} do
      assert :ok =
               GenServer.call(
                 server,
                 {:register_function, {"success", &DummyFunctions.success/0, 2_000, 1_000}}
               )
    end

    test "doesn't allow registering under the same key twice", %{server: server} do
      assert :ok =
               GenServer.call(
                 server,
                 {:register_function, {"success", &DummyFunctions.success/0, 2_000, 1_000}}
               )

      assert {:error, :already_registered} =
               GenServer.call(
                 server,
                 {:register_function, {"success", &DummyFunctions.success/0, 2_000, 1_000}}
               )
    end
  end

  describe "retrieval" do
    setup do
      {:ok, server} = start_supervised(Cache.Server)

      {:ok, server: server}
    end

    test "returns the value of the registered function", %{server: server} do
      :ok =
        GenServer.call(
          server,
          {:register_function, {"success", &DummyFunctions.success/0, 2_000, 1_000}}
        )

      assert {:ok, 42} = GenServer.call(server, {:get, {"success", 1_000, []}})
    end

    test "returns error when function is not registered", %{server: server} do
      assert {:error, :not_registered} =
               GenServer.call(server, {:get, {"unregistered", 1_000, []}})
    end

    test "gives the last value when function is recomputed", %{server: server} do
      # Dummy GenServer takes 60 sec to update. We set up long ttl and short
      # refresh rate to see that it uses old value when calculating the new one.
      start_supervised(DummyGenServer)

      :ok =
        GenServer.call(
          server,
          {:register_function, {"changing", &DummyFunctions.changing/0, 60_000, 100}}
        )

      assert {:ok, 0} = GenServer.call(server, {:get, {"changing", 2000, []}})
      Process.sleep(200)
      assert {:ok, 0} = GenServer.call(server, {:get, {"changing", 2000, []}})
    end

    test "waits for timeout when result unavailable", %{server: server} do
      :ok =
        GenServer.call(
          server,
          {:register_function,
           {"success_with_delay", &DummyFunctions.success_with_delay/0, 2_000, 1_000}}
        )

      assert {:ok, 42} = GenServer.call(server, {:get, {"success_with_delay", 2000, []}})
    end

    test "results in error if timeout is reached", %{server: server} do
      :ok =
        GenServer.call(
          server,
          {:register_function,
           {"success_with_delay", &DummyFunctions.success_with_delay/0, 2_000, 1_000}}
        )

      assert {:error, :timeout} = GenServer.call(server, {:get, {"success_with_delay", 100, []}})
    end

    test "erroring function is treated as providing no value", %{server: server} do
      :ok =
        GenServer.call(
          server,
          {:register_function, {"failure", &DummyFunctions.failure/0, 2_000, 1_000}}
        )

      assert {:error, :timeout} = GenServer.call(server, {:get, {"failure", 100, []}})
    end
  end
end
