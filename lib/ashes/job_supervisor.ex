defmodule JobSupervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def start_child(name, data) do
    Supervisor.start_child(__MODULE__, [{name, data}])
  end

  def init(:ok) do
    children = [
      worker(GenServer, [Job], restart: :transient)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end
