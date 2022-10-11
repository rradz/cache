defmodule Cache.Server do
  @moduledoc """
  GenServer implementing cache.
  """

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(_opts) do
    pid = Cache.Store.start_link()
    {:ok, %{store: pid, function_map: %{}}}
  end

  def handle_call({:register_function, {key, fun, ttl, refresh_interval}}, _from, state) do
    case Map.get(fun_map, key) do
      nil ->
        new_state =
          Map.put(fun_map, key, %{function: fun, ttl: ttl, refresh_interval: refresh_interval})

        {:reply, :ok, new_state}

      _ ->
        {:reply, {:error, :already_registered}, state}
    end
  end

  def handle_info({:recalculate_function, {key, ttl, refresh_interval}}, state) do
    %{function: fun} = Map.get(state, key)
    server_pid = self()

    Process.spawn(
      fn ->
        case fun.() do
          {:ok, value} ->
            send(server_pid, {:update_function_value, {key, value, ttl}})

          _ ->
            nil
        end
      end,
      [:link]
    )
  end

  def handle_info({:update_function_value, {key, value, ttl}}, state) do
  end
end
