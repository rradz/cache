defmodule Cache do
  use GenServer

  @type result ::
          {:ok, any()}
          | {:error, :timeout}
          | {:error, :not_registered}

  @process_registered_name __MODULE__

  # Client API

  @doc ~s"""
  Registers a function that will be computed periodically to update the cache.

  Arguments:
    - `fun`: a 0-arity function that computes the value and returns either
      `{:ok, value}` or `{:error, reason}`.
    - `key`: associated with the function and is used to retrieve the stored
    value.
    - `ttl` ("time to live"): how long (in milliseconds) the value is stored
      before it is discarded if the value is not refreshed.
    - `refresh_interval`: how often (in milliseconds) the function is
      recomputed and the new value stored. `refresh_interval` must be strictly
      smaller than `ttl`. After the value is refreshed, the `ttl` counter is
      restarted.

  The value is stored only if `{:ok, value}` is returned by `fun`. If `{:error,
  reason}` is returned, the value is not stored and `fun` must be retried on
  the next run.
  """
  @spec register_function(
          fun :: (() -> {:ok, any()} | {:error, any()}),
          key :: any,
          ttl :: non_neg_integer(),
          refresh_interval :: non_neg_integer()
        ) :: :ok | {:error, :already_registered}
  def register_function(fun, key, ttl, refresh_interval)
      when is_function(fun, 0) and is_integer(ttl) and ttl > 0 and
             is_integer(refresh_interval) and
             refresh_interval < ttl do
    GenServer.call(
      @process_registered_name,
      {:register_function, {key, fun, ttl, refresh_interval}}
    )
  end

  @doc ~s"""
  Get the value associated with `key`.

  Details:
    - If the value for `key` is stored in the cache, the value is returned
      immediately.
    - If a recomputation of the function is in progress, the last stored value
      is returned.
    - If the value for `key` is not stored in the cache but a computation of
      the function associated with this `key` is in progress, wait up to
      `timeout` milliseconds. If the value is computed within this interval,
      the value is returned. If the computation does not finish in this
      interval, `{:error, :timeout}` is returned.
    - If `key` is not associated with any function, return `{:error,
      :not_registered}`
  """
  @spec get(any(), non_neg_integer(), Keyword.t()) :: result
  def get(key, timeout \\ 30_000, opts \\ []) when is_integer(timeout) and timeout > 0 do
    GenServer.call(@process_registered_name, {:get, {key, timeout, opts}})
  end

  # Implementation
  @impl GenServer
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @process_registered_name)
  end

  @imp GenServer
  def init(_opts) do
    {:ok, %{functions: %{}}}
  end

  @impl GenServer
  def handle_call(
        {:register_function, {key, fun, ttl, refresh_interval}},
        _from,
        %{functions: functions} = state
      ) do
    case Map.get(functions, key) do
      nil ->
        new_functions =
          Map.put(functions, key, %{
            function: fun,
            ttl: ttl,
            refresh_interval: refresh_interval,
            last_value: :undefined
          })

        pid = self()

        Process.spawn(
          fn ->
            case fun.() do
              {:ok, result} ->
                send(pid, {:update, {key, result}})

              _ ->
                nil
            end
          end,
          [:link]
        )

        {:reply, :ok, %{state | functions: new_functions}}

      _ ->
        {:reply, {:error, :already_registered}, state}
    end
  end

  @impl GenServer
  def handle_call({:get, {key, timeout, _opts}}, _from, %{functions: functions} = state) do
    case Map.get(functions, key) do
      nil -> {:reply, {:error, :not_registered}, state}
      %{last_value: :undefined} -> {:noreply, state}
      %{last_value: value} -> {:reply, {:ok, value}, state}
    end
  end

  @impl GenServer
  def handle_info({:update, {key, value}}, %{functions: functions} = state) do
    new_functions =
      Map.update(functions, key, %{}, fn old_record -> %{old_record | last_value: value} end)

    {:noreply, %{state | functions: new_functions}}
  end
end

defmodule Cache.Store do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def store(store, key, value, ttl) do
    GenServer.cast(store, {:store, {key, value, ttl}})
  end

  def get(store, key) do
    GenServer.call(store, {:get, key})
  end
end
