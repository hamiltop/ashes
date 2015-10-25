defmodule Ashes.PageController do
  use Ashes.Web, :controller

  require Logger

  def index(conn, _params) do
    render conn, "index.html"
  end

  def github_api(conn, params) do
    name = params["repository"]["name"]
    GenServer.cast(JobManager, {:clone, name, params})
    text conn, "ok"
  end
end
