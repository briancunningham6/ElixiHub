# Simple script to check MCP servers in the database
# Run with: mix run check_mcp_servers.exs

alias Elixihub.MCP
alias Elixihub.Repo

IO.puts("Checking MCP servers in the database...")

# Check if MCP servers exist
case MCP.list_servers() do
  [] ->
    IO.puts("No MCP servers found in the database.")
  servers ->
    IO.puts("Found #{length(servers)} MCP server(s):")
    Enum.each(servers, fn server ->
      IO.puts("- Name: #{server.name}")
      IO.puts("  URL: #{server.url}")
      IO.puts("  Status: #{server.status}")
      IO.puts("  Description: #{server.description}")
      IO.puts("  Tools: #{length(server.tools)}")
      if length(server.tools) > 0 do
        Enum.each(server.tools, fn tool ->
          IO.puts("    - #{tool.name}: #{tool.description}")
        end)
      end
      IO.puts("")
    end)
end

# Check discovery info
IO.puts("Discovery information:")
discovery_info = MCP.get_discovery_info()
case discovery_info do
  [] ->
    IO.puts("No active MCP servers available for discovery.")
  servers ->
    IO.puts("#{length(servers)} server(s) available for discovery:")
    Enum.each(servers, fn server ->
      IO.puts("- #{server.name} (#{server.url}) - #{length(server.tools)} tools")
    end)
end

# Check all tools
IO.puts("\nAll available tools:")
all_tools = MCP.list_all_tools()
case all_tools do
  [] ->
    IO.puts("No tools available.")
  tools ->
    IO.puts("#{length(tools)} tool(s) available:")
    Enum.each(tools, fn tool ->
      IO.puts("- #{tool.name} (from #{tool.server_name}): #{tool.description}")
    end)
end

IO.puts("\nMCP server check completed.")