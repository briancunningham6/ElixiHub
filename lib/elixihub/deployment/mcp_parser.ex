defmodule Elixihub.Deployment.MCPParser do
  @moduledoc """
  Parses MCP server configuration and tool definitions from deployed applications.
  """

  @doc """
  Extracts MCP server configuration and tools from an application directory.
  
  Looks for MCP definitions in the following locations:
  - mcp.json
  - config/mcp.json
  - .elixihub/mcp.json
  - package.json (for Node.js apps with elixihub.mcp field)
  - mix.exs (for Elixir apps with elixihub_mcp function)
  
  Additionally, it will attempt to discover tools by making a request to the 
  MCP server endpoint if it's available.
  """
  def extract_mcp_info(connection, app_path, app) do
    IO.puts("Extracting MCP info from app path: #{app_path}")
    
    config_files = [
      "#{app_path}/mcp.json",
      "#{app_path}/config/mcp.json", 
      "#{app_path}/.elixihub/mcp.json",
      "#{app_path}/package.json",
      "#{app_path}/mix.exs"
    ]

    IO.puts("Looking for MCP config files: #{inspect(config_files)}")
    
    case extract_from_files(connection, config_files, app) do
      {:ok, mcp_config} ->
        # Try to get tools from the live server if it has a URL
        case get_tools_from_server(mcp_config) do
          {:ok, tools} ->
            {:ok, Map.put(mcp_config, :tools, tools)}
          {:error, _reason} ->
            # Fall back to tools defined in config
            {:ok, mcp_config}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_from_files(connection, files, app) do
    Enum.reduce_while(files, {:error, :no_config_found}, fn file, acc ->
      IO.puts("Checking MCP config file: #{file}")
      case extract_from_file(connection, file, app) do
        {:ok, config} when config != %{} -> 
          IO.puts("Found MCP config in #{file}")
          {:halt, {:ok, config}}
        {:ok, %{}} -> 
          IO.puts("No MCP config found in #{file}")
          {:cont, acc}
        {:error, reason} -> 
          IO.puts("Failed to read #{file}: #{inspect(reason)}")
          {:cont, acc}
      end
    end)
  end

  defp extract_from_file(connection, file_path, app) do
    case Elixihub.Deployment.SSHClient.execute_command(connection, "cat #{file_path}") do
      {:ok, {content, _stderr, 0}} ->
        parse_file_content(file_path, String.trim(content), app)
      
      {:ok, {_stdout, _stderr, _exit_code}} ->
        {:error, :file_not_found}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_file_content(file_path, content, app) do
    cond do
      String.ends_with?(file_path, "mcp.json") ->
        parse_mcp_json(content, app)
      
      String.ends_with?(file_path, "package.json") ->
        parse_package_json(content, app)
      
      String.ends_with?(file_path, "mix.exs") ->
        parse_mix_exs(content, app)
      
      true ->
        {:error, :unsupported_file_type}
    end
  end

  defp parse_mcp_json(content, app) do
    case Jason.decode(content) do
      {:ok, %{"server" => server_config}} ->
        config = normalize_server_config(server_config, app)
        tools = Map.get(server_config, "tools", [])
        {:ok, Map.put(config, :tools, normalize_tools(tools))}
      
      {:ok, server_config} when is_map(server_config) ->
        config = normalize_server_config(server_config, app)
        tools = Map.get(server_config, "tools", [])
        {:ok, Map.put(config, :tools, normalize_tools(tools))}
      
      {:ok, _} ->
        {:error, :invalid_format}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_package_json(content, app) do
    case Jason.decode(content) do
      {:ok, %{"elixihub" => %{"mcp" => mcp_config}}} when is_map(mcp_config) ->
        config = normalize_server_config(mcp_config, app)
        tools = Map.get(mcp_config, "tools", [])
        {:ok, Map.put(config, :tools, normalize_tools(tools))}
      
      {:ok, _} ->
        {:ok, %{}}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_mix_exs(content, app) do
    # Look for elixihub_mcp function definition
    case Regex.run(~r/def elixihub_mcp.*?do\s*(.*?)\s*end/s, content) do
      [_full, mcp_code] ->
        case extract_mcp_from_elixir_code(mcp_code, app) do
          {:ok, config} -> {:ok, config}
          {:error, reason} -> {:error, reason}
        end
      
      nil ->
        {:ok, %{}}
    end
  end

  defp extract_mcp_from_elixir_code(_code, app) do
    # For now, provide a default configuration for Elixir apps
    # In the future, this could parse the actual Elixir code
    default_config = %{
      name: app.name,
      url: determine_app_url(app),
      description: "MCP server for #{app.name}",
      version: "1.0.0",
      tools: []
    }
    
    {:ok, default_config}
  end

  defp normalize_server_config(config, app) do
    %{
      name: config["name"] || app.name,
      url: config["url"] || determine_app_url(app),
      description: config["description"] || "MCP server for #{app.name}",
      version: config["version"] || "1.0.0",
      metadata: Map.drop(config, ["name", "url", "description", "version", "tools"])
    }
  end

  defp normalize_tools(tools) when is_list(tools) do
    Enum.map(tools, &normalize_tool/1)
  end
  defp normalize_tools(_), do: []

  defp normalize_tool(tool) when is_map(tool) do
    %{
      "name" => tool["name"],
      "description" => tool["description"] || "",
      "inputSchema" => tool["inputSchema"] || tool["input_schema"] || %{}
    }
  end

  defp determine_app_url(app) do
    # Try to construct the MCP endpoint URL for the app
    cond do
      app.url && String.contains?(app.url, "http") ->
        # Use the app's configured URL and append /mcp endpoint
        base_url = String.trim_trailing(app.url, "/")
        "#{base_url}/mcp"
      
      app.deploy_path ->
        # Try to determine from deployment info
        "http://localhost:4001/mcp"  # Default for now
      
      true ->
        "http://localhost:4001/mcp"  # Fallback
    end
  end

  defp get_tools_from_server(%{url: url}) when is_binary(url) do
    IO.puts("Attempting to get tools from live MCP server at: #{url}")
    
    request_body = %{
      jsonrpc: "2.0",
      id: generate_request_id(),
      method: "tools/list"
    }

    headers = [
      {"Content-Type", "application/json"},
      {"User-Agent", "ElixiHub-Deployment/1.0"}
    ]

    case HTTPoison.post(url, Jason.encode!(request_body), headers, recv_timeout: 10_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"result" => %{"tools" => tools}}} ->
            IO.puts("Successfully received #{length(tools)} tools from live server")
            {:ok, tools}
          
          {:ok, %{"error" => error}} ->
            IO.puts("MCP server returned error: #{inspect(error)}")
            {:error, error}
          
          {:error, decode_error} ->
            IO.puts("Failed to decode response: #{inspect(decode_error)}")
            {:error, {:decode_error, decode_error}}
        end
      
      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        IO.puts("HTTP error from MCP server: #{status_code}")
        {:error, {:http_error, status_code}}
      
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts("Connection error to MCP server: #{inspect(reason)}")
        {:error, {:connection_error, reason}}
    end
  rescue
    error ->
      IO.puts("Exception when calling MCP server: #{inspect(error)}")
      {:error, {:exception, error}}
  end

  defp get_tools_from_server(_), do: {:error, :no_url}

  defp generate_request_id do
    :crypto.strong_rand_bytes(16) |> Base.hex_encode32(case: :lower)
  end
end