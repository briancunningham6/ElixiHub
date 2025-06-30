defmodule Elixihub.MCP do
  @moduledoc """
  The MCP context for managing Model Context Protocol servers and tools.
  
  This module provides functionality to:
  - Register MCP servers from deployed applications
  - Store and manage available tools from each server  
  - Provide discovery API for applications to find available tools
  - Handle server lifecycle (register/unregister during app deployment/undeployment)
  """

  import Ecto.Query, warn: false
  alias Elixihub.Repo
  alias Elixihub.MCP.{Server, Tool}
  alias Elixihub.Apps.App

  @doc """
  Returns the list of MCP servers.
  """
  def list_servers do
    Repo.all(Server) |> Repo.preload(:tools)
  end

  @doc """
  Gets a single MCP server.
  """
  def get_server!(id), do: Repo.get!(Server, id) |> Repo.preload(:tools)

  @doc """
  Gets an MCP server by app_id.
  """
  def get_server_by_app(app_id) do
    Repo.get_by(Server, app_id: app_id) |> Repo.preload(:tools)
  end

  @doc """
  Creates an MCP server registration.
  """
  def create_server(attrs \\ %{}) do
    %Server{}
    |> Server.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an MCP server.
  """
  def update_server(%Server{} = server, attrs) do
    server
    |> Server.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an MCP server and all its tools.
  """
  def delete_server(%Server{} = server) do
    Repo.delete(server)
  end

  @doc """
  Creates an MCP tool.
  """
  def create_tool(attrs \\ %{}) do
    %Tool{}
    |> Tool.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an MCP tool.
  """
  def update_tool(%Tool{} = tool, attrs) do
    tool
    |> Tool.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an MCP tool.
  """
  def delete_tool(%Tool{} = tool) do
    Repo.delete(tool)
  end

  @doc """
  Registers an MCP server and its tools for an application during deployment.
  """
  def register_mcp_server_for_app(%App{} = app, server_config, tools) do
    Repo.transaction(fn ->
      # Remove existing server and tools for this app
      case get_server_by_app(app.id) do
        nil -> :ok
        existing_server -> delete_server(existing_server)
      end

      # Create new server
      server_attrs = %{
        app_id: app.id,
        name: server_config[:name] || app.name,
        url: server_config[:url],
        description: server_config[:description] || "MCP server for #{app.name}",
        version: server_config[:version] || "1.0.0",
        status: "active"
      }

      case create_server(server_attrs) do
        {:ok, server} ->
          # Create tools for this server
          tool_results = Enum.map(tools, fn tool ->
            tool_attrs = %{
              server_id: server.id,
              name: tool["name"],
              description: tool["description"],
              input_schema: tool["inputSchema"] || %{},
              metadata: Map.drop(tool, ["name", "description", "inputSchema"])
            }
            create_tool(tool_attrs)
          end)

          # Check if all tools were created successfully
          failed_tools = Enum.filter(tool_results, fn
            {:ok, _} -> false
            {:error, _} -> true
          end)

          if Enum.empty?(failed_tools) do
            server_with_tools = Repo.preload(server, :tools)
            {:ok, server_with_tools}
          else
            Repo.rollback({:error, :tool_creation_failed, failed_tools})
          end

        {:error, reason} ->
          Repo.rollback({:error, :server_creation_failed, reason})
      end
    end)
  end

  @doc """
  Unregisters the MCP server for an application during undeployment.
  """
  def unregister_mcp_server_for_app(%App{} = app) do
    case get_server_by_app(app.id) do
      nil -> {:ok, :no_server_registered}
      server -> delete_server(server)
    end
  end

  @doc """
  Gets all available tools across all registered MCP servers.
  """
  def list_all_tools do
    from(t in Tool,
      join: s in Server, on: t.server_id == s.id,
      where: s.status == "active",
      select: %{
        id: t.id,
        name: t.name,
        description: t.description,
        input_schema: t.input_schema,
        metadata: t.metadata,
        server_name: s.name,
        server_url: s.url,
        app_id: s.app_id
      }
    )
    |> Repo.all()
  end

  @doc """
  Gets all available tools for a specific server.
  """
  def list_tools_for_server(server_id) do
    from(t in Tool, where: t.server_id == ^server_id)
    |> Repo.all()
  end

  @doc """
  Gets discovery information for all active MCP servers.
  This is used by applications like Agent app to discover available MCP servers.
  """
  def get_discovery_info do
    servers = from(s in Server,
      where: s.status == "active",
      select: %{
        id: s.id,
        name: s.name,
        url: s.url,
        description: s.description,
        version: s.version,
        app_id: s.app_id,
        updated_at: s.updated_at
      }
    )
    |> Repo.all()

    tools_by_server = from(t in Tool,
      join: s in Server, on: t.server_id == s.id,
      where: s.status == "active",
      select: %{
        server_id: s.id,
        tool: %{
          name: t.name,
          description: t.description,
          input_schema: t.input_schema
        }
      }
    )
    |> Repo.all()
    |> Enum.group_by(& &1.server_id, & &1.tool)

    Enum.map(servers, fn server ->
      Map.put(server, :tools, Map.get(tools_by_server, server.id, []))
    end)
  end

  @doc """
  Updates the status of an MCP server.
  """
  def update_server_status(%Server{} = server, status) do
    update_server(server, %{status: status})
  end
end