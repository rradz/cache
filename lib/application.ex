defmodule Cache.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Cache.Server, [name: Cache.process_name()]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
