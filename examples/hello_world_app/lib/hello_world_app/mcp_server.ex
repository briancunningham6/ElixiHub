defmodule HelloWorldApp.MCPServer do
  @moduledoc """
  MCP (Model Context Protocol) server implementation for Hello World App.
  Provides tools that can be called by AI agents.
  """

  require Logger

  @tools [
    %{
      "name" => "get_personalized_greeting",
      "description" => "Get a personalized hello world greeting for a user",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{
          "style" => %{
            "type" => "string",
            "description" => "The greeting style (formal, casual, friendly, enthusiastic)",
            "enum" => ["formal", "casual", "friendly", "enthusiastic"]
          },
          "include_time" => %{
            "type" => "boolean",
            "description" => "Whether to include the current time in the greeting"
          }
        },
        "required" => []
      }
    },
    %{
      "name" => "get_app_info",
      "description" => "Get information about the Hello World application",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{},
        "required" => []
      }
    }
  ]

  def handle_request(method, params, user_context \\ %{}) do
    case method do
      "tools/list" ->
        {:ok, %{"tools" => @tools}}
      
      "tools/call" ->
        handle_tool_call(params, user_context)
      
      _ ->
        {:error, %{"code" => -32601, "message" => "Method not found"}}
    end
  end

  defp handle_tool_call(%{"name" => tool_name, "arguments" => arguments}, user_context) do
    case tool_name do
      "get_personalized_greeting" ->
        get_personalized_greeting(arguments, user_context)
      
      "get_app_info" ->
        get_app_info(arguments, user_context)
      
      _ ->
        {:error, %{"code" => -32602, "message" => "Tool not found"}}
    end
  end

  defp handle_tool_call(_, _) do
    {:error, %{"code" => -32602, "message" => "Invalid tool call parameters"}}
  end

  defp get_personalized_greeting(arguments, user_context) do
    username = Map.get(user_context, "username", "World")
    style = Map.get(arguments, "style", "friendly")
    include_time = Map.get(arguments, "include_time", false)

    base_greeting = case style do
      "formal" ->
        "Good day, #{username}. Welcome to our Hello World application."
      
      "casual" ->
        "Hey #{username}! Welcome to Hello World."
      
      "friendly" ->
        "Hello #{username}! It's great to see you here in our Hello World app."
      
      "enthusiastic" ->
        "Hello #{username}! 🎉 Welcome to the amazing Hello World experience!"
      
      _ ->
        "Hello #{username}! Welcome to Hello World."
    end

    greeting = if include_time do
      current_time = DateTime.utc_now() |> DateTime.to_string()
      "#{base_greeting} The current time is #{current_time}."
    else
      base_greeting
    end

    result = %{
      "greeting" => greeting,
      "user" => username,
      "style" => style,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "app" => "hello_world_app"
    }

    Logger.info("Generated personalized greeting for user: #{username}")
    
    {:ok, result}
  end

  defp get_app_info(_arguments, _user_context) do
    result = %{
      "name" => "Hello World App",
      "version" => "0.1.0",
      "description" => "A simple Hello World application with MCP support",
      "capabilities" => [
        "Personalized greetings",
        "MCP tool integration",
        "ElixiHub authentication"
      ],
      "mcp_tools" => Enum.map(@tools, & &1["name"]),
      "status" => "active",
      "uptime" => get_uptime()
    }

    {:ok, result}
  end

  defp get_uptime do
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    uptime_seconds = div(uptime_ms, 1000)
    
    hours = div(uptime_seconds, 3600)
    minutes = div(rem(uptime_seconds, 3600), 60)
    seconds = rem(uptime_seconds, 60)
    
    "#{hours}h #{minutes}m #{seconds}s"
  end

  def get_available_tools do
    @tools
  end
end