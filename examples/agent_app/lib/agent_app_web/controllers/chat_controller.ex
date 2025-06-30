defmodule AgentAppWeb.ChatController do
  use Phoenix.Controller,
    formats: [:html, :json],
    layouts: [html: AgentAppWeb.Layouts]
    
  import Plug.Conn

  def create(conn, %{"message" => message}) do
    current_user = AgentApp.Auth.get_current_user(conn)
    
    # Process the chat message
    case process_chat_message(message, current_user) do
      {:ok, response} ->
        json(conn, %{
          status: "success",
          response: response,
          timestamp: DateTime.utc_now()
        })
      
      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{
          status: "error",
          error: inspect(reason),
          timestamp: DateTime.utc_now()
        })
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{status: "error", error: "Message is required"})
  end

  defp process_chat_message(message, user) do
    # Get available tools
    case AgentApp.MCPManager.list_available_tools() do
      {:ok, tools} ->
        # Prepare messages for OpenAI
        messages = [
          %{
            role: "system",
            content: build_system_prompt(tools, user)
          },
          %{
            role: "user",
            content: message
          }
        ]

        # Call OpenAI
        case AgentApp.OpenAIClient.chat_completion(messages, tools) do
          {:ok, %{type: :text, content: response}} ->
            {:ok, %{type: "text", content: response}}
          
          {:ok, %{type: :tool_calls, tool_calls: tool_calls}} ->
            # Execute tool calls
            user_context = %{
              user_id: user.user_id,
              username: user.username
            }
            
            tool_results = AgentApp.OpenAIClient.execute_tool_calls(tool_calls, user_context)
            
            # Get final response from OpenAI with tool results
            final_messages = messages ++ [
              %{
                role: "assistant",
                tool_calls: Enum.map(tool_calls, fn tool_call ->
                  %{
                    id: tool_call.id,
                    type: "function",
                    function: %{
                      name: tool_call.name,
                      arguments: Jason.encode!(tool_call.arguments)
                    }
                  }
                end)
              }
            ] ++ tool_results

            case AgentApp.OpenAIClient.chat_completion(final_messages, []) do
              {:ok, %{type: :text, content: final_response}} ->
                {:ok, %{
                  type: "text_with_tools",
                  content: final_response,
                  tools_called: Enum.map(tool_calls, & &1.name)
                }}
              
              {:error, reason} ->
                {:error, reason}
            end
          
          {:error, reason} ->
            {:error, reason}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_system_prompt(available_tools, user) do
    tools_description = if Enum.any?(available_tools) do
      tool_list = Enum.map(available_tools, fn tool ->
        "- #{tool["name"]}: #{tool["description"]}"
      end) |> Enum.join("\n")

      "\n\nYou have access to the following tools:\n#{tool_list}\n\nUse these tools when appropriate to help the user."
    else
      ""
    end

    """
    You are a helpful AI assistant integrated with ElixiHub. You can help users interact with various applications and services.
    
    Current user: #{user.username} (ID: #{user.user_id})
    
    #{tools_description}
    
    Be helpful, concise, and friendly. When using tools, explain what you're doing and why.
    """
  end
end