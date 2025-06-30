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
    servers = Application.get_env(:agent_app, :mcp)[:servers] || []
    
    state = %__MODULE__{
      servers: servers,
      connections: %{}
    }

    # Initialize connections to MCP servers
    send(self(), :connect_servers)
    
    {:ok, state}
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
    tools = Enum.flat_map(state.connections, fn {server_name, connection} ->
      case get_server_tools(connection) do
        {:ok, server_tools} ->
          Enum.map(server_tools, fn tool ->
            Map.put(tool, :server, server_name)
          end)
        
        {:error, _} ->
          []
      end
    end)

    {:reply, {:ok, tools}, state}
  end

  # Public API

  def call_tool(server_name, tool_name, params, user_context \\ %{}) do
    GenServer.call(__MODULE__, {:call_tool, server_name, tool_name, params, user_context})
  end

  def list_available_tools do
    GenServer.call(__MODULE__, :list_available_tools)
  end

  # Private functions

  defp connect_to_server(server) do
    # For now, we'll simulate the connection. In a real implementation,
    # this would establish an HTTP or WebSocket connection to the MCP server
    {:ok, %{
      name: server.name,
      url: server.url,
      description: server.description,
      connected_at: DateTime.utc_now()
    }}
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
            {:ok, tools}
          
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

  defp generate_request_id do
    :crypto.strong_rand_bytes(16) |> Base.hex_encode32(case: :lower)
  end
end