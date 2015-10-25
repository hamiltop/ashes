defmodule GithubWebhookPlug do
  import Plug.Conn
  
  def init(options) do
    options
  end

  def call(conn, options) do
    mount = Dict.get(options, :mount)
    case hd(conn.path_info) do
      ^mount -> github_api(conn, options)
      _ -> conn
    end
    # if not mount matches => return
    # if no signature => error
    # if signature doesn't match => error
    # done.
  end

  def github_api(conn, options) do
    key = Dict.get(options, :secret)
    {:ok, body, _} = read_body(conn)
    signature = case get_req_header(conn, "x-hub-signature") do
      ["sha1=" <> signature  | []] -> 
        {:ok, signature} = Base.decode16(signature, case: :lower) 
        signature
      x -> x
    end
    hmac = :crypto.hmac(:sha, key, body)
    case hmac do
      ^signature ->
        params = Poison.decode!(body)
        name = params["repository"]["name"]
        GenServer.cast(JobManager, {:clone, name, params})
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, "Hello world")
        |> halt
      _ ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(401, "Not Authorized")
        |> halt
    end
  end
end
