defmodule ElixiPathWeb.CopypartyController do
  use ElixiPathWeb, :controller
  require Logger

  # Handle static assets without authentication
  def proxy_static(conn, %{"path" => path}) do
    Logger.info("Copyparty static asset request for: #{inspect(path)}")
    
    # Build the full path for copyparty static assets
    copyparty_url = ElixiPath.CopypartyManager.get_copyparty_url()
    full_path = "/.cpr/" <> Enum.join(path, "/")
    
    # Add query string if present
    query_string = if conn.query_string != "", do: "?" <> conn.query_string, else: ""
    target_url = copyparty_url <> full_path <> query_string
    
    # Simple headers for static assets (no authentication)
    headers = [{"User-Agent", "ElixiPath/1.0"}]
    
    # Add original headers (except host and authorization)
    original_headers = Enum.reject(conn.req_headers, fn {key, _} -> 
      String.downcase(key) in ["host", "authorization"]
    end)
    
    all_headers = headers ++ original_headers
    
    # Forward as GET request to copyparty
    proxy_get_request(conn, target_url, all_headers)
  end

  def proxy(conn, %{"path" => path}) do
    # Get authenticated user from session
    user = conn.assigns[:current_user]
    
    full_path = "/" <> Enum.join(path, "/")
    Logger.info("Copyparty proxy request for path: #{full_path} by user: #{user && user.email}")
    
    # Forward request to Copyparty
    copyparty_url = ElixiPath.CopypartyManager.get_copyparty_url()
    
    # Add query string if present
    query_string = if conn.query_string != "", do: "?" <> conn.query_string, else: ""
    target_url = copyparty_url <> full_path <> query_string
    
    # Use copyparty IdP header authentication
    headers = [
      {"X-Remote-User", user && user.email},
      {"User-Agent", "Mozilla/5.0 (ElixiPath/1.0)"},
      {"Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"}
    ]
    
    # Add original headers (except host and authorization)
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
    Logger.info("Making GET request to: #{url} with headers: #{inspect(headers)}")
    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: status, headers: resp_headers, body: body}} ->
        # Filter response headers
        filtered_headers = filter_response_headers(resp_headers)
        
        # Rewrite HTML content to fix asset paths
        rewritten_body = rewrite_asset_paths(body, resp_headers)
        
        conn
        |> add_response_headers(filtered_headers)
        |> send_resp(status, rewritten_body)
      
      {:error, reason} ->
        Logger.error("Copyparty proxy GET error: #{inspect(reason)}")
        send_resp(conn, 502, "Bad Gateway")
    end
  end
  
  defp rewrite_asset_paths(body, headers) do
    # Check if this is HTML content
    content_type = Enum.find_value(headers, fn 
      {key, value} when key in ["Content-Type", "content-type"] -> value
      _ -> nil
    end)
    
    if content_type && String.contains?(content_type, "text/html") do
      # Rewrite /.cpr/ paths to /ui/.cpr/
      body
      |> String.replace(~r/href="\/\.cpr\//, "href=\"/ui/.cpr/")
      |> String.replace(~r/src="\/\.cpr\//, "src=\"/ui/.cpr/")
      |> String.replace(~r/url\("\/\.cpr\//, "url(\"/ui/.cpr/")
    else
      body
    end
  end
  
  defp rewrite_asset_paths(body, headers) do
    # Check if this is HTML content
    content_type = Enum.find_value(headers, fn 
      {key, value} when key in ["Content-Type", "content-type"] -> value
      _ -> nil
    end)
    
    if content_type && String.contains?(content_type, "text/html") do
      # Rewrite /.cpr/ paths to /ui/.cpr/
      body
      |> String.replace(~r/href="\/\.cpr\//, "href=\"/ui/.cpr/")
      |> String.replace(~r/src="\/\.cpr\//, "src=\"/ui/.cpr/")
      |> String.replace(~r/url\("\/\.cpr\//, "url(\"/ui/.cpr/")
    else
      body
    end
  end

  defp proxy_post_request(conn, url, headers) do
    # Read request body with larger limits for file uploads
    {:ok, body, _conn} = Plug.Conn.read_body(conn, length: 500_000_000) # 500MB limit
    
    # Add content-type if present
    content_type = get_req_header(conn, "content-type") |> List.first()
    headers = if content_type, do: [{"Content-Type", content_type} | headers], else: headers
    
    # Use longer timeout for file uploads
    options = [timeout: 300_000, recv_timeout: 300_000] # 5 minute timeout
    
    case HTTPoison.post(url, body, headers, options) do
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