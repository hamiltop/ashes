defmodule JobManager do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_cast({:clone, name, data}, state) do
    {:ok, pid} = JobSupervisor.start_child(name, data)
    state = Dict.put(state, name, pid)
    {:noreply, state}
  end
end
