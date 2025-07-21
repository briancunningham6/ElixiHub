defmodule AgentAppWeb.ChatLive do
  use Phoenix.LiveView, layout: {AgentAppWeb.Layouts, :app}
  
  require Logger

  @impl true
  def mount(_params, session, socket) do
    Logger.info("ChatLive mount - session keys: #{inspect(Map.keys(session))}")
    Logger.info("ChatLive mount - socket assigns: #{inspect(Map.keys(socket.assigns))}")
    
    # Check authentication at LiveView level with better debugging
    current_user = case socket.assigns[:current_user] do
      nil -> 
        Logger.info("No current_user in assigns, checking session")
        case Map.get(session, "auth_token") do
          token when is_binary(token) ->
            Logger.info("Found auth_token in session, verifying...")
            case AgentApp.Auth.verify_token(token) do
              {:ok, user} -> 
                Logger.info("Token verification successful: #{inspect(user)}")
                user
              {:error, reason} -> 
                Logger.warning("Token verification failed: #{inspect(reason)}")
                nil
            end
          other ->
            Logger.warning("No valid auth_token in session: #{inspect(other)}")
            nil
        end
      user -> 
        Logger.info("Using current_user from assigns: #{inspect(user)}")
        user
    end
    
    # Always allow mount but show different content based on auth
    socket =
      socket
      |> assign(:messages, [])
      |> assign(:input_message, "")
      |> assign(:loading, false)
      |> assign(:available_tools, [])
      |> assign(:mcp_servers, [])
      |> assign(:current_user, current_user || %{username: "Guest", user_id: nil, email: nil})

    # Load tools/servers in background
    send(self(), :load_mcp_data)
    
    {:ok, socket}
  end

  @impl true
  def handle_info(:load_mcp_data, socket) do
    # Load MCP data in background to avoid blocking mount
    try do
      tools = case AgentApp.MCPManager.list_available_tools() do
        {:ok, tools} -> tools
        {:error, _} -> []
      end

      servers = case AgentApp.MCPManager.list_mcp_servers() do
        {:ok, servers} -> servers
        {:error, _} -> []
      end

      socket =
        socket
        |> assign(:available_tools, tools)
        |> assign(:mcp_servers, servers)

      {:noreply, socket}
    rescue
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    # Add user message to conversation
    user_message = %{
      role: "user",
      content: message,
      timestamp: DateTime.utc_now()
    }

    messages = socket.assigns.messages ++ [user_message]
    
    socket =
      socket
      |> assign(:messages, messages)
      |> assign(:input_message, "")
      |> assign(:loading, true)

    # Process the message asynchronously
    send(self(), {:process_message, message, messages})

    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_input", %{"message" => message}, socket) do
    {:noreply, assign(socket, :input_message, message)}
  end

  @impl true
  def handle_event("clear_chat", _params, socket) do
    {:noreply, assign(socket, :messages, [])}
  end

  @impl true
  def handle_info({:process_message, user_input, conversation_messages}, socket) do
    # Prepare messages for OpenAI
    openai_messages = prepare_openai_messages(conversation_messages)
    
    # Add system message with available tools context
    system_message = %{
      role: "system",
      content: build_system_prompt(socket.assigns.available_tools, socket.assigns.current_user)
    }

    full_messages = [system_message] ++ openai_messages

    # Check if OpenAI is configured
    openai_config = Application.get_env(:agent_app, :openai)
    api_key = openai_config[:api_key]
    
    if api_key && api_key != "your_openai_api_key_here" do
      case AgentApp.OpenAIClient.chat_completion(full_messages, socket.assigns.available_tools) do
        {:ok, %{type: :text, content: response}} ->
          # Simple text response
          assistant_message = %{
            role: "assistant",
            content: response,
            timestamp: DateTime.utc_now()
          }

          socket =
            socket
            |> assign(:messages, socket.assigns.messages ++ [assistant_message])
            |> assign(:loading, false)

          {:noreply, socket}

        {:ok, %{type: :tool_calls, tool_calls: tool_calls}} ->
          # AI wants to call tools
          handle_tool_calls(tool_calls, socket)

        {:error, reason} ->
          Logger.error("OpenAI API error: #{inspect(reason)}")
          
          error_message = %{
            role: "assistant",
            content: "I'm sorry, I encountered an error processing your request. Please try again.",
            timestamp: DateTime.utc_now(),
            error: true
          }

          socket =
            socket
            |> assign(:messages, socket.assigns.messages ++ [error_message])
            |> assign(:loading, false)

          {:noreply, socket}
      end
    else
      # Fallback response when OpenAI is not configured
      fallback_message = %{
        role: "assistant", 
        content: "Hello! I'm the ElixiHub Agent, but I'm not fully configured yet. To enable AI chat functionality, please configure the OPENAI_API_KEY environment variable. For now, I can still help you test the MCP tools if they're available.",
        timestamp: DateTime.utc_now()
      }

      socket =
        socket
        |> assign(:messages, socket.assigns.messages ++ [fallback_message])
        |> assign(:loading, false)

      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:tool_results, tool_results, original_tool_calls}, socket) do
    # Process tool call results and get final response
    conversation_messages = socket.assigns.messages
    openai_messages = prepare_openai_messages(conversation_messages)
    
    # Add the assistant's tool call message
    tool_call_message = %{
      role: "assistant",
      tool_calls: Enum.map(original_tool_calls, fn tool_call ->
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

    # Add tool results
    messages_with_tools = [tool_call_message] ++ tool_results

    system_message = %{
      role: "system",
      content: build_system_prompt(socket.assigns.available_tools, socket.assigns.current_user)
    }

    full_messages = [system_message] ++ openai_messages ++ messages_with_tools

    case AgentApp.OpenAIClient.chat_completion(full_messages, []) do
      {:ok, %{type: :text, content: response}} ->
        assistant_message = %{
          role: "assistant",
          content: response,
          timestamp: DateTime.utc_now()
        }

        socket =
          socket
          |> assign(:messages, socket.assigns.messages ++ [assistant_message])
          |> assign(:loading, false)

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("OpenAI API error processing tool results: #{inspect(reason)}")
        
        error_message = %{
          role: "assistant",
          content: "I was able to call the requested function, but encountered an error generating the final response.",
          timestamp: DateTime.utc_now(),
          error: true
        }

        socket =
          socket
          |> assign(:messages, socket.assigns.messages ++ [error_message])
          |> assign(:loading, false)

        {:noreply, socket}
    end
  end

  defp handle_tool_calls(tool_calls, socket) do
    # Execute tool calls asynchronously
    user_context = %{
      user_id: socket.assigns.current_user.user_id,
      username: socket.assigns.current_user.username,
      auth_token: get_session(socket, :auth_token)
    }

    Task.async(fn ->
      tool_results = AgentApp.OpenAIClient.execute_tool_calls(tool_calls, user_context)
      send(self(), {:tool_results, tool_results, tool_calls})
    end)

    {:noreply, socket}
  end

  defp prepare_openai_messages(messages) do
    Enum.map(messages, fn message ->
      %{
        role: message.role,
        content: message.content
      }
    end)
  end

  defp build_system_prompt(available_tools, current_user) do
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
    
    Current user: #{current_user.username} (ID: #{current_user.user_id})
    
    #{tools_description}
    
    Be helpful, concise, and friendly. When using tools, explain what you're doing and why.
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <div class="bg-white rounded-lg shadow-lg overflow-hidden">
        <!-- Header -->
        <div class="bg-blue-600 px-6 py-4">
          <div class="flex items-center justify-between">
            <h1 class="text-xl font-semibold text-white">AI Chat Assistant</h1>
            <div class="flex items-center space-x-4">
              <button
                phx-click="clear_chat"
                class="text-blue-100 hover:text-white text-sm underline"
              >
                Clear Chat
              </button>
            </div>
          </div>
        </div>

        <!-- Chat Messages -->
        <div class="h-96 overflow-y-auto p-6 space-y-4" id="chat-messages">
            <%= if Enum.empty?(@messages) do %>
              <div class="text-center text-gray-500 py-8">
                <p>Hello! I'm your ElixiHub Agent. I can help you interact with various applications.</p>
                <p class="mt-2 text-sm">Try asking me: "Get a personalized hello world for me"</p>
              </div>
            <% end %>

            <%= for message <- @messages do %>
              <div class={[
                "flex",
                if message.role == "user" do
                  "justify-end"
                else
                  "justify-start"
                end
              ]}>
                <div class={[
                  "max-w-xs lg:max-w-md px-4 py-2 rounded-lg",
                  if message.role == "user" do
                    "bg-blue-600 text-white"
                  else
                    if Map.get(message, :error) do
                      "bg-red-100 text-red-800 border border-red-200"
                    else
                      "bg-gray-200 text-gray-800"
                    end
                  end
                ]}>
                  <p class="text-sm"><%= message.content %></p>
                  <p class="text-xs mt-1 opacity-70">
                    <%= Calendar.strftime(message.timestamp, "%H:%M:%S") %>
                  </p>
                </div>
              </div>
            <% end %>

            <%= if @loading do %>
              <div class="flex justify-start">
                <div class="bg-gray-200 text-gray-800 max-w-xs lg:max-w-md px-4 py-2 rounded-lg">
                  <div class="flex items-center space-x-2">
                    <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-gray-600"></div>
                    <span class="text-sm">Thinking...</span>
                  </div>
                </div>
              </div>
            <% end %>
        </div>

        <!-- Input Area -->
        <div class="border-t bg-gray-50 px-6 py-4">
          <form phx-submit="send_message" class="flex space-x-3">
            <input
              type="text"
              name="message"
              value={@input_message}
              phx-change="update_input"
              placeholder="Type your message..."
              disabled={@loading}
              class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 disabled:bg-gray-100 disabled:cursor-not-allowed"
              autocomplete="off"
            />
            <button
              type="submit"
              disabled={@loading or @input_message == ""}
              class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:bg-gray-400 disabled:cursor-not-allowed"
            >
              <%= if @loading do %>
                <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
              <% end %>
              Send
            </button>
          </form>
        </div>

        <!-- Available Tools Info -->
        <%= if Enum.any?(@available_tools) do %>
          <div class="border-t bg-gray-50 px-6 py-3">
            <details class="text-sm text-gray-600">
              <summary class="cursor-pointer hover:text-gray-800">
                Available Tools (<%= length(@available_tools) %>)
              </summary>
              <ul class="mt-2 space-y-1">
                <%= for tool <- @available_tools do %>
                  <li>
                    <strong><%= tool["name"] %></strong>: <%= tool["description"] %>
                    <span class="text-gray-500">(<%= tool.server %>)</span>
                  </li>
                <% end %>
              </ul>
            </details>
          </div>
        <% end %>

        <!-- MCP Servers Info -->
        <div class="border-t bg-gray-50 px-6 py-3">
          <details class="text-sm text-gray-600" open>
            <summary class="cursor-pointer hover:text-gray-800 font-semibold">
              MCP Servers (<%= length(@mcp_servers) %>)
            </summary>
            <%= if Enum.any?(@mcp_servers) do %>
              <div class="mt-3 space-y-2">
                <%= for server <- @mcp_servers do %>
                  <div class="bg-white rounded border p-3">
                    <div class="flex items-center justify-between">
                      <div>
                        <div class="font-medium text-gray-900"><%= server.name %></div>
                        <div class="text-xs text-gray-500"><%= server.description %></div>
                        <div class="text-xs text-gray-400 mt-1">
                          URL: <%= server.url %> | Version: <%= server.version %>
                        </div>
                      </div>
                      <div class="flex-shrink-0">
                        <span class={[
                          "inline-flex items-center px-2 py-1 rounded-full text-xs font-medium",
                          if server.status == "connected" do
                            "bg-green-100 text-green-800"
                          else
                            "bg-red-100 text-red-800"
                          end
                        ]}>
                          <%= server.status %>
                        </span>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% else %>
              <div class="mt-2 text-gray-500 italic">
                No MCP servers discovered. Deploy applications with MCP configuration to see them here.
              </div>
            <% end %>
          </details>
        </div>
      </div>
    </div>

    <script>
      // Auto-scroll to bottom of chat
      document.addEventListener('DOMContentLoaded', function() {
        const chatMessages = document.getElementById('chat-messages');
        if (chatMessages) {
          chatMessages.scrollTop = chatMessages.scrollHeight;
        }
      });

      // Auto-scroll when new messages arrive
      window.addEventListener('phx:update', function() {
        const chatMessages = document.getElementById('chat-messages');
        if (chatMessages) {
          setTimeout(() => {
            chatMessages.scrollTop = chatMessages.scrollHeight;
          }, 100);
        }
      });
    </script>
    """
  end
end