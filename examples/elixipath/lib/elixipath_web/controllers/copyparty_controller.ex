defmodule ElixiPathWeb.CopypartyController do
  use ElixiPathWeb, :controller
  require Logger

  def proxy(conn, %{"path" => path}) do
    user = conn.assigns[:current_user]
    Logger.info("Copyparty proxy request for path: #{inspect(path)} by user: #{user.email}")
    
    # Forward request to Copyparty with authentication headers
    copyparty_url = ElixiPath.CopypartyManager.get_copyparty_url()
    full_path = "/" <> Enum.join(path, "/")
    
    # Add query string if present
    query_string = if conn.query_string != "", do: "?" <> conn.query_string, else: ""
    target_url = copyparty_url <> full_path <> query_string
    
    # Get auth token from session
    auth_token = get_session(conn, "auth_token")
    
    headers = [
      {"Authorization", "Bearer #{auth_token}"},
      {"X-User-Email", user.email},
      {"User-Agent", "ElixiPath/1.0"}
    ]
    
    # Add original headers (except host)
    original_headers = Enum.reject(conn.req_headers, fn {key, _} -> 
      String.downcase(key) in ["host", "authorization"]
    end)
    
    all_headers = headers ++ original_headers
    
    # Forward request based on method
    case conn.method do
      "GET" ->
        proxy_get_request(conn, target_url, all_headers)
      
      "POST" ->
        proxy_post_request(conn, target_url, all_headers)
      
      "PUT" ->
        proxy_put_request(conn, target_url, all_headers)
      
      "DELETE" ->
        proxy_delete_request(conn, target_url, all_headers)
      
      method ->
        Logger.warning("Unsupported HTTP method: #{method}")
        send_resp(conn, 405, "Method Not Allowed")
    end
  end

  defp proxy_get_request(conn, url, headers) do
    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: status, headers: resp_headers, body: body}} ->
        # Filter response headers
        filtered_headers = filter_response_headers(resp_headers)
        
        conn
        |> add_response_headers(filtered_headers)
        |> send_resp(status, body)
      
      {:error, reason} ->
        Logger.error("Copyparty proxy GET error: #{inspect(reason)}")
        send_resp(conn, 502, "Bad Gateway")
    end
  end

  defp proxy_post_request(conn, url, headers) do
    # Read request body
    {:ok, body, _conn} = Plug.Conn.read_body(conn, length: 100_000_000) # 100MB limit
    
    # Add content-type if present
    content_type = get_req_header(conn, "content-type") |> List.first()
    headers = if content_type, do: [{"Content-Type", content_type} | headers], else: headers
    
    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: status, headers: resp_headers, body: resp_body}} ->
        filtered_headers = filter_response_headers(resp_headers)
        
        conn
        |> add_response_headers(filtered_headers)
        |> send_resp(status, resp_body)
      
      {:error, reason} ->
        Logger.error("Copyparty proxy POST error: #{inspect(reason)}")
        send_resp(conn, 502, "Bad Gateway")
    end
  end

  defp proxy_put_request(conn, url, headers) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn, length: 100_000_000)
    
    content_type = get_req_header(conn, "content-type") |> List.first()
    headers = if content_type, do: [{"Content-Type", content_type} | headers], else: headers
    
    case HTTPoison.put(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: status, headers: resp_headers, body: resp_body}} ->
        filtered_headers = filter_response_headers(resp_headers)
        
        conn
        |> add_response_headers(filtered_headers)
        |> send_resp(status, resp_body)
      
      {:error, reason} ->
        Logger.error("Copyparty proxy PUT error: #{inspect(reason)}")
        send_resp(conn, 502, "Bad Gateway")
    end
  end

  defp proxy_delete_request(conn, url, headers) do
    case HTTPoison.delete(url, headers) do
      {:ok, %HTTPoison.Response{status_code: status, headers: resp_headers, body: resp_body}} ->
        filtered_headers = filter_response_headers(resp_headers)
        
        conn
        |> add_response_headers(filtered_headers)
        |> send_resp(status, resp_body)
      
      {:error, reason} ->
        Logger.error("Copyparty proxy DELETE error: #{inspect(reason)}")
        send_resp(conn, 502, "Bad Gateway")
    end
  end

  defp filter_response_headers(headers) do
    # Remove headers that shouldn't be forwarded
    excluded = ["transfer-encoding", "connection", "upgrade"]
    
    Enum.reject(headers, fn {key, _value} ->
      String.downcase(key) in excluded
    end)
  end

  defp add_response_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {key, value}, acc ->
      put_resp_header(acc, String.downcase(key), value)
    end)
  end
end