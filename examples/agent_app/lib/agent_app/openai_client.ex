defmodule AgentApp.OpenAIClient do
  @moduledoc """
  OpenAI API client for chat completions with function calling support.
  """

  require Logger

  @default_model "gpt-4o-mini"
  @default_max_tokens 1000
  @default_temperature 0.7

  def chat_completion(messages, available_tools \\ [], opts \\ []) do
    model = Keyword.get(opts, :model, @default_model)
    max_tokens = Keyword.get(opts, :max_tokens, @default_max_tokens)
    temperature = Keyword.get(opts, :temperature, @default_temperature)

    request_body = %{
      model: model,
      messages: messages,
      max_tokens: max_tokens,
      temperature: temperature
    }

    # Add tools if available
    request_body = if Enum.any?(available_tools) do
      functions = Enum.map(available_tools, &tool_to_function/1)
      Map.merge(request_body, %{
        tools: functions,
        tool_choice: "auto"
      })
    else
      request_body
    end

    case make_request("/chat/completions", request_body) do
      {:ok, response} ->
        process_chat_response(response)
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_chat_response(%{"choices" => [choice | _]}) do
    message = choice["message"]
    
    cond do
      # Regular text response
      message["content"] && !message["tool_calls"] ->
        {:ok, %{type: :text, content: message["content"]}}
      
      # Function/tool call response
      message["tool_calls"] ->
        tool_calls = Enum.map(message["tool_calls"], fn tool_call ->
          %{
            id: tool_call["id"],
            name: tool_call["function"]["name"],
            arguments: Jason.decode!(tool_call["function"]["arguments"])
          }
        end)
        
        {:ok, %{type: :tool_calls, tool_calls: tool_calls}}
      
      # Empty response
      true ->
        {:ok, %{type: :text, content: "I'm sorry, I couldn't generate a response."}}
    end
  end

  defp process_chat_response(_), do: {:error, :invalid_response}

  defp tool_to_function(tool) do
    %{
      type: "function",
      function: %{
        name: tool["name"],
        description: tool["description"],
        parameters: tool["inputSchema"] || %{
          type: "object",
          properties: %{},
          required: []
        }
      }
    }
  end

  def execute_tool_calls(tool_calls, user_context) do
    Enum.map(tool_calls, fn tool_call ->
      case AgentApp.MCPManager.call_tool(
        "hello_world", # For now, we assume all tools come from hello_world server
        tool_call.name,
        tool_call.arguments,
        user_context
      ) do
        {:ok, result} ->
          %{
            tool_call_id: tool_call.id,
            role: "tool",
            name: tool_call.name,
            content: Jason.encode!(result)
          }
        
        {:error, reason} ->
          %{
            tool_call_id: tool_call.id,
            role: "tool",
            name: tool_call.name,
            content: Jason.encode!(%{error: inspect(reason)})
          }
      end
    end)
  end

  defp make_request(endpoint, body) do
    config = Application.get_env(:agent_app, :openai)
    api_key = config[:api_key]
    
    if !api_key do
      return {:error, :no_api_key}
    end

    url = "https://api.openai.com/v1" <> endpoint
    
    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"},
      {"User-Agent", "AgentApp/1.0"}
    ]

    http_options = config[:http_options] || []

    case HTTPoison.post(url, Jason.encode!(body), headers, http_options) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, decoded} -> {:ok, decoded}
          {:error, reason} -> {:error, {:decode_error, reason}}
        end
      
      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"error" => error}} ->
            {:error, {:api_error, status_code, error}}
          
          _ ->
            {:error, {:http_error, status_code, response_body}}
        end
      
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, {:connection_error, reason}}
    end
  end
end