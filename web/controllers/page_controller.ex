defmodule Ashes.PageController do
  use Ashes.Web, :controller

  require Logger

  def index(conn, _params) do
    render conn, "index.html"
  end
end
