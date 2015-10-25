defmodule Job do
  use GenServer

  require Logger

  defmacrop next_state(state, status, [do: block]) do
    quote do
      task = Task.async fn ->
        unquote(block)
      end
      Dict.put(unquote(state), :status, unquote(status))
        |> Dict.put(:task, task)
    end
  end

  def init({"", _}) do
    raise "problem"
  end
  def init({name, data}) do
    dir = Path.join(["/var", "local", "ashes", "build", name])
    repo = data["repository"]["url"]
    output = OutputCollector.new(self)
    {bash_env, 0} = System.cmd("/bin/bash", ["-l", "-c", "env"])
    path_env = String.split(bash_env)
      |> Enum.find(&String.starts_with?(&1, "PATH="))
      |> String.split("=")
      |> List.to_tuple
    env = [{"MIX_ENV", "prod"}, path_env]
    state = %{
      dir: dir,
      data: data,
      output: output,
      env: env,
      name: name}
    state = case File.dir?(dir) do
      true ->
        next_state(state, :clone) do
          System.cmd "git", ["fetch"], env: env, cd: dir, into: output, stderr_to_stdout: true
          System.cmd "mix", ["clean", repo, dir], env: env, cd: dir, into: output, stderr_to_stdout: true
        end
      false ->
        File.mkdir(dir)
        next_state(state, :clone) do
          System.cmd "git", ["clone", repo, dir], env: env, cd: dir, into: output, stderr_to_stdout: true
        end
    end
    {:ok, state}
  end

  def handle_call(:status, _from, state = %{status: status}) do
    {:reply, status, state}
  end

  def handle_info({ref, msg}, state = %{
      task: %Task{ref: ref},
      status: status,
      data: data,
      dir: dir,
      output: output,
      env: env,
      name: name
    }) do
    Process.demonitor(ref, [:flush])
    case status do
      :clone ->
        state = next_state(state, :checkout) do
          System.cmd "git", ["checkout", data["after"]], cd: dir, env: env, into: output, stderr_to_stdout: true
        end
        {:noreply, state}
      :checkout ->
        state = next_state(state, :version) do
          System.cmd "git", ["rev-list", "HEAD", "--count"], cd: dir, env: env
        end
        {:noreply, state}
      :version ->
        {version, 0} = msg
        state = next_state(state, :deps) do
          System.cmd "mix", ["deps.get"], cd: dir, env: env, into: output, stderr_to_stdout: true
        end
        state = Dict.put(state, :version, "0.0." <> String.strip(version))
        state = Dict.put(state, :env, [{"BUILD_VERSION", state[:version]} | env])
        {:noreply, state}
      :deps ->
        state = next_state(state, :assets) do
          File.mkdir(Path.join([dir, "priv"]))
          File.mkdir(Path.join([dir, "priv", "static"]))
          System.cmd "npm", ["install"], cd: dir, env: env, into: output, stderr_to_stdout: true
          System.cmd "node", ["node_modules/brunch/bin/brunch", "build", "--production"], cd: dir, env: env, into: output, stderr_to_stdout: true
          System.cmd "mix", ["phoenix.digest"], cd: dir, env: env, into: output, stderr_to_stdout: true
        end
        {:noreply, state}
      :assets ->
        state = next_state(state, :compile) do
          System.cmd "mix", ["compile"], cd: dir, env: env, into: output, stderr_to_stdout: true
        end
        {:noreply, state}
      :compile ->
        state = next_state(state, :release) do
          System.cmd "mix", ["release", "--verbosity=verbose"], env: env, cd: dir, into: output, stderr_to_stdout: true
        end
        {:noreply, state}
      :release ->
        state = next_state(state, :upgrade) do
          run_dir = Path.join(["/var", "local", "ashes", "run", name])
          target_dir = Path.join([run_dir, "releases", state[:version]])
          File.mkdir(target_dir)
          filename = name <> ".tar.gz"
          File.cp(
            Path.join([dir, "rel", name, "releases", state[:version], filename]),
            Path.join([target_dir, filename])
          )
          bin = Path.join([run_dir, "bin", name])
          System.cmd bin, ["upgrade", state[:version]], cd: dir, into: output, stderr_to_stdout: true
        end
        {:noreply, state}
      :upgrade ->
        {:stop, :normal, state}
    end
  end

  def handle_info({ref, msg}, state = %{output: %OutputCollector{ref: ref}}) do
    Logger.debug(String.strip(msg))
    {:noreply, state}
  end
end
