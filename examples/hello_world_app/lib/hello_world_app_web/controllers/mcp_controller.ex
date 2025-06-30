defmodule HelloWorldAppWeb.MCPController do
  use HelloWorldAppWeb, :controller
  
  require Logger

  def handle_request(conn, _params) do
    case Jason.decode(conn.assigns.raw_body || "{}") do
      {:ok, %{"jsonrpc" => "2.0", "method" => method, "params" => params, "id" => id}} ->
        # Extract user context from the authenticated request
        user_context = extract_user_context(conn)
        
        # Handle the MCP request
        case HelloWorldApp.MCPServer.handle_request(method, params, user_context) do
          {:ok, result} ->
            response = %{
              "jsonrpc" => "2.0",
              "id" => id,
              "result" => result
            }
            
            json(conn, response)
          
          {:error, error} ->
            response = %{
              "jsonrpc" => "2.0",
              "id" => id,
              "error" => error
            }
            
            json(conn, response)
        end
      
      {:ok, %{"jsonrpc" => "2.0", "method" => method, "params" => params}} ->
        # Notification (no id)
        user_context = extract_user_context(conn)
        
        case HelloWorldApp.MCPServer.handle_request(method, params, user_context) do
          {:ok, _result} ->
            # Notifications don't require a response
            send_resp(conn, 204, "")
          
          {:error, _error} ->
            # Log the error but don't send a response for notifications
            Logger.warning("MCP notification failed: #{method}")
            send_resp(conn, 204, "")
        end
      
      {:ok, invalid_request} ->
        Logger.warning("Invalid MCP request: #{inspect(invalid_request)}")
        
        response = %{
          "jsonrpc" => "2.0",
          "id" => nil,
          "error" => %{
            "code" => -32600,
            "message" => "Invalid Request"
          }
        }
        
        conn
        |> put_status(400)
        |> json(response)
      
      {:error, _decode_error} ->
        response = %{
          "jsonrpc" => "2.0",
          "id" => nil,
          "error" => %{
            "code" => -32700,
            "message" => "Parse error"
          }
        }
        
        conn
        |> put_status(400)
        |> json(response)
    end
  end

  def tools(conn, _params) do
    # Endpoint to list available tools (for discovery)
    tools = HelloWorldApp.MCPServer.get_available_tools()
    json(conn, %{"tools" => tools})
  end

  defp extract_user_context(conn) do
    case conn.assigns[:current_user] do
      %{user_id: user_id, username: username} ->
        %{
          "user_id" => user_id,
          "username" => username
        }
      
      _ ->
        %{}
    end
  end

  # Plug to capture raw body for JSON-RPC parsing
  def capture_raw_body(conn, _opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    Plug.Conn.assign(conn, :raw_body, body)
  end
end