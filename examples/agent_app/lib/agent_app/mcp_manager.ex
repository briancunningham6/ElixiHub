defmodule AgentApp.MCPManager do
  @moduledoc """
  Manages MCP (Model Context Protocol) connections to other ElixiHub applications.
  """

  use GenServer
  require Logger

  defstruct [:servers, :connections]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("MCPManager initializing - will discover servers from ElixiHub")
    
    state = %__MODULE__{
      servers: [],
      connections: %{}
    }

    # Discover and connect to MCP servers from ElixiHub
    send(self(), :discover_and_connect_servers)
    
    {:ok, state}
  end

  def handle_info(:discover_and_connect_servers, state) do
    Logger.info("Discovering MCP servers from ElixiHub...")
    
    case discover_mcp_servers() do
      {:ok, servers} ->
        Logger.info("Discovered #{length(servers)} MCP servers from ElixiHub")
        
        connections = Enum.reduce(servers, %{}, fn server, acc ->
          case connect_to_server(server) do
            {:ok, conn} ->
              Logger.info("Connected to MCP server: #{server.name}")
              Map.put(acc, server.name, conn)
            
            {:error, reason} ->
              Logger.warning("Failed to connect to MCP server #{server.name}: #{inspect(reason)}")
              acc
          end
        end)

        {:noreply, %{state | servers: servers, connections: connections}}
      
      {:error, reason} ->
        Logger.warning("Failed to discover MCP servers: #{inspect(reason)}. Will retry in 5 seconds...")
        Process.send_after(self(), :discover_and_connect_servers, 5_000)
        {:noreply, state}
    end
  end

  def handle_info(:connect_servers, state) do
    connections = Enum.reduce(state.servers, %{}, fn server, acc ->
      case connect_to_server(server) do
        {:ok, conn} ->
          Logger.info("Connected to MCP server: #{server.name}")
          Map.put(acc, server.name, conn)
        
        {:error, reason} ->
          Logger.warning("Failed to connect to MCP server #{server.name}: #{inspect(reason)}")
          acc
      end
    end)

    {:noreply, %{state | connections: connections}}
  end

  def handle_call({:call_tool, server_name, tool_name, params, user_context}, _from, state) do
    case Map.get(state.connections, server_name) do
      nil ->
        {:reply, {:error, :server_not_connected}, state}
      
      connection ->
        result = call_mcp_tool(connection, tool_name, params, user_context)
        {:reply, result, state}
    end
  end

  def handle_call(:list_available_tools, _from, state) do
    Logger.info("Listing available tools from #{map_size(state.connections)} connections")
    
    tools = try do
      Enum.flat_map(state.connections, fn {server_name, connection} ->
        Logger.info("Getting tools from server: #{server_name} with connection: #{inspect(connection)}")
        
        case get_server_tools(connection) do
          {:ok, server_tools} ->
            Logger.info("Got #{length(server_tools)} tools from #{server_name}")
            Enum.map(server_tools, fn tool ->
              Map.put(tool, :server, server_name)
            end)
          
          {:error, reason} ->
            Logger.warning("Failed to get tools from #{server_name}: #{inspect(reason)}")
            []
        end
      end)
    rescue
      error ->
        Logger.error("Error in list_available_tools: #{inspect(error)}")
        Logger.error("Stacktrace: #{inspect(__STACKTRACE__)}")
        []
    end

    Logger.info("Returning #{length(tools)} total tools")
    {:reply, {:ok, tools}, state}
  end

  def handle_call(:list_mcp_servers, _from, state) do
    servers_info = Enum.map(state.servers, fn server ->
      connection_status = if Map.has_key?(state.connections, server.name) do
        "connected"
      else
        "disconnected"
      end
      
      %{
        name: server.name,
        url: server.url,
        description: server.description,
        version: server.version,
        status: connection_status,
        app_id: server.app_id
      }
    end)
    
    {:reply, {:ok, servers_info}, state}
  end

  # Public API

  def call_tool(server_name, tool_name, params, user_context \\ %{}) do
    GenServer.call(__MODULE__, {:call_tool, server_name, tool_name, params, user_context})
  end

  def list_available_tools do
    GenServer.call(__MODULE__, :list_available_tools)
  end

  def list_mcp_servers do
    GenServer.call(__MODULE__, :list_mcp_servers)
  end

  # Private functions

  defp connect_to_server(server) do
    # Validate server configuration
    case validate_server_config(server) do
      :ok ->
        # For now, we'll simulate the connection. In a real implementation,
        # this would establish an HTTP or WebSocket connection to the MCP server
        {:ok, %{
          name: server.name,
          url: server.url,
          description: server.description,
          connected_at: DateTime.utc_now()
        }}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp validate_server_config(server) do
    cond do
      is_nil(server.url) or server.url == "" ->
        {:error, "Server URL is empty or nil"}
      
      not String.starts_with?(server.url, "http") ->
        {:error, "Server URL must start with http:// or https://"}
      
      String.contains?(server.url, "your_") ->
        {:error, "Server URL appears to be a placeholder value"}
      
      true ->
        :ok
    end
  end

  defp call_mcp_tool(connection, tool_name, params, user_context) do
    # Prepare the MCP tool call request
    request_body = %{
      jsonrpc: "2.0",
      id: generate_request_id(),
      method: "tools/call",
      params: %{
        name: tool_name,
        arguments: params,
        context: user_context
      }
    }

    # Make HTTP request to the MCP server
    headers = [
      {"Content-Type", "application/json"},
      {"User-Agent", "AgentApp/1.0"}
    ]

    case HTTPoison.post(connection.url, Jason.encode!(request_body), headers, recv_timeout: 30_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"result" => result}} ->
            {:ok, result}
          
          {:ok, %{"error" => error}} ->
            {:error, error}
          
          {:error, decode_error} ->
            {:error, {:decode_error, decode_error}}
        end
      
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        {:error, {:http_error, status_code, body}}
      
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, {:connection_error, reason}}
    end
  end

  defp get_server_tools(connection) do
    # Validate connection before making request
    if is_nil(connection.url) or connection.url == "" do
      Logger.warning("Cannot get tools from server #{connection.name}: URL is empty")
      {:error, :empty_url}
    else
      Logger.info("Getting tools from MCP server: #{connection.name} at #{connection.url}")
      
      # Get available tools from the MCP server
      request_body = %{
        jsonrpc: "2.0",
        id: generate_request_id(),
        method: "tools/list"
      }

      headers = [
        {"Content-Type", "application/json"},
        {"User-Agent", "AgentApp/1.0"}
      ]

      case HTTPoison.post(connection.url, Jason.encode!(request_body), headers, recv_timeout: 10_000) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          case Jason.decode(body) do
            {:ok, %{"result" => %{"tools" => tools}}} ->
              Logger.info("Successfully received #{length(tools)} tools from #{connection.name}")
              {:ok, tools}
            
            {:ok, %{"error" => error}} ->
              Logger.warning("MCP server #{connection.name} returned error: #{inspect(error)}")
              {:error, error}
            
            {:error, decode_error} ->
              Logger.warning("Failed to decode response from #{connection.name}: #{inspect(decode_error)}")
              {:error, {:decode_error, decode_error}}
          end
        
        {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
          Logger.warning("HTTP error from #{connection.name}: #{status_code} - #{body}")
          {:error, {:http_error, status_code, body}}
        
        {:error, %HTTPoison.Error{reason: reason}} ->
          Logger.warning("Connection error to #{connection.name}: #{inspect(reason)}")
          {:error, {:connection_error, reason}}
        
        {:error, other} ->
          Logger.warning("Unexpected error calling #{connection.name}: #{inspect(other)}")
          {:error, {:unexpected_error, other}}
      end
    end
  end

  defp generate_request_id do
    :crypto.strong_rand_bytes(16) |> Base.hex_encode32(case: :lower)
  end

  defp discover_mcp_servers do
    # Get ElixiHub configuration
    elixihub_config = Application.get_env(:agent_app, :elixihub)
    base_url = (elixihub_config && elixihub_config[:elixihub_url]) || "http://localhost:4005"
    
    # Get authentication token
    auth_config = Application.get_env(:agent_app, :auth)
    token = auth_config && auth_config[:jwt_token]
    
    discovery_url = "#{base_url}/api/mcp/discovery"
    
    headers = [
      {"Content-Type", "application/json"},
      {"User-Agent", "AgentApp/1.0"}
    ]
    
    headers = if token do
      [{"Authorization", "Bearer #{token}"} | headers]
    else
      headers
    end
    
    Logger.info("Discovering MCP servers from: #{discovery_url}")
    
    case HTTPoison.get(discovery_url, headers, recv_timeout: 10_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"servers" => servers}} ->
            normalized_servers = Enum.map(servers, &normalize_discovered_server/1)
            {:ok, normalized_servers}
          
          {:ok, servers} when is_list(servers) ->
            normalized_servers = Enum.map(servers, &normalize_discovered_server/1)
            {:ok, normalized_servers}
          
          {:error, decode_error} ->
            Logger.error("Failed to decode discovery response: #{inspect(decode_error)}")
            {:error, {:decode_error, decode_error}}
        end
      
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("HTTP error from discovery endpoint: #{status_code} - #{body}")
        {:error, {:http_error, status_code, body}}
      
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Connection error to discovery endpoint: #{inspect(reason)}")
        {:error, {:connection_error, reason}}
    end
  rescue
    error ->
      Logger.error("Exception during MCP server discovery: #{inspect(error)}")
      {:error, {:exception, error}}
  end

  defp normalize_discovered_server(server) do
    %{
      name: server["name"],
      url: server["url"],
      description: server["description"] || "",
      version: server["version"] || "1.0.0",
      app_id: server["app_id"]
    }
  end
end