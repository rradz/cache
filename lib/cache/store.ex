  defmodule Cache.Store do
    @moduledoc """
    Module for storing function values until ttl is exceeded.
    """
    use GenServer

    # API
    def store(store, key, value, ttl) do
      GenServer.cast(store, {:store, {key, value, ttl}})
    end

    def get(store, key) do
      GenServer.call(store, {:get, key})
    end

    # Implementation

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, opts)
    end

    def init(_opts) do
      {:ok, %{}}
    end

    def handle_cast({:store, {key, value, ttl}}, state) do
      timestamp = System.os_time(:millisecond)
      new_state = Map.put(state, key, %{value: value, timestamp: timestamp})

      Process.send_after(self(), {:expire, {key, timestamp}}, ttl)

      {:noreply, new_state}
    end

    def handle_info({:expire, {key, timestamp}}, state) do
      # If value timestamp is the same as when we scheduled expire, we remove the value.
      # Otherwise, value has already been updated, so we ignore the expire.
      case Map.get(state, key) do
        %{timestamp: ^timestamp} ->
          {:noreply, Map.delete(state, key)}

        _ ->
          {:noreply, state}
      end
    end

    def handle_call({:get, key}, _from, state) do
      case Map.get(state, key) do
        %{value: value} -> {:reply, {:ok, value}, state}
        _ -> {:reply, :no_value, state}
      end
    end
  end
