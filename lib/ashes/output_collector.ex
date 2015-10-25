defmodule OutputCollector do
  defstruct [:pid, :ref]

  def new(pid) do
    %__MODULE__{pid: pid, ref: make_ref}
  end
end

defimpl Collectable, for: OutputCollector do
  def into(val) do
    {val, fn
      o = %OutputCollector{pid: pid, ref: ref}, {:cont, data} ->
        send pid, {ref, data}
        o
      o, :done ->
        o
      _, :halt ->
        :ok
    end}
  end
end
