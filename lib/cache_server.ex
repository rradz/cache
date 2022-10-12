defmodule Cache.Server do
  @moduledoc """
  GenServer implementing cache.
  """

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(_opts) do
    {:ok, pid} = Cache.Store.start_link()
    {:ok, %{store: pid, function_map: %{}}}
  end

  def handle_call(
        {:register_function, {key, fun, ttl, refresh_interval}},
        _from,
        %{function_map: function_map} = state
      ) do
    case Map.get(function_map, key) do
      nil ->
        new_function_map =
          Map.put(function_map, key, %{
            function: fun,
            ttl: ttl,
            refresh_interval: refresh_interval
          })

        send(self(), {:recalculate_function, {key, ttl, refresh_interval}})

        {:reply, :ok, %{state | function_map: new_function_map}}

      _ ->
        {:reply, {:error, :already_registered}, state}
    end
  end

  def handle_info(
        {:recalculate_function, {key, ttl, refresh_interval}},
        %{function_map: function_map} = state
      ) do
    %{function: fun} = Map.get(function_map, key)
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

    Process.send_after(
      server_pid,
      {:recalculate_function, {key, ttl, refresh_interval}},
      refresh_interval
    )

    {:noreply, state}
  end

  def handle_info({:update_function_value, {key, value, ttl}}, %{store: store} = state) do
    Cache.Store.store(store, key, value, ttl)

    {:noreply, state}
  end

  def handle_call(
        {:get, {key, timeout, _opts}},
        from,
        %{store: store, function_map: function_map} = state
      ) do
    with %{} <- Map.get(function_map, key, :not_registered),
         {:ok, value} <- Cache.Store.get(store, key) do
      {:reply, {:ok, value}, state}
    else
      :not_registered ->
        {:reply, {:error, :not_registered}, state}

      :no_value ->
        Process.send_after(self(), {:delayed_get, {key, from}}, timeout)
        {:noreply, state}
    end
  end

  def handle_info({:delayed_get, {key, from}}, %{store: store} = state) do
    case Cache.Store.get(store, key) do
      {:ok, value} ->
        GenServer.reply(from, {:ok, value})

      _ ->
        GenServer.reply(from, {:error, :timeout})
    end

    {:noreply, state}
  end
end
