defmodule ElixihubWeb.Admin.ShellLive.Index do
  use ElixihubWeb, :live_view

  alias Elixihub.Nodes
  alias Elixihub.Authorization
  alias Elixihub.Shell

  on_mount {ElixihubWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(%{"node_id" => node_id}, _session, socket) do
    user = socket.assigns.current_user
    
    unless Authorization.user_has_permission?(user, "admin:access") do
      {:ok, redirect(socket, to: ~p"/")}
    else
      node = Nodes.get_node!(node_id)
      
      # Initialize shell session
      session_id = generate_session_id()
      
      {:ok,
       socket
       |> assign(:node, node)
       |> assign(:session_id, session_id)
       |> assign(:output_lines, [])
       |> assign(:current_input, "")
       |> assign(:command_history, [])
       |> assign(:history_index, -1)
       |> assign(:connected, Nodes.node_connected?(node))
       |> assign(:page_title, "IEx Shell - #{node.name}@#{node.host}")
      }
    end
  end

  @impl true
  def handle_event("execute_command", %{"command" => command}, socket) do
    if String.trim(command) == "" do
      {:noreply, socket}
    else
      node = socket.assigns.node
      _session_id = socket.assigns.session_id
      
      # Add command to history
      new_history = [command | socket.assigns.command_history] |> Enum.take(100)
      
      # Add command to output
      prompt_line = "iex(#{node.name})> #{command}"
      new_output = [prompt_line | socket.assigns.output_lines]
      
      # Execute command on remote node
      case Shell.execute_on_node(node, command) do
        {:ok, result} ->
          result_lines = Shell.format_result(result)
          final_output = result_lines ++ new_output
          
          {:noreply,
           socket
           |> assign(:output_lines, final_output)
           |> assign(:current_input, "")
           |> assign(:command_history, new_history)
           |> assign(:history_index, -1)
          }
        
        {:error, reason} ->
          error_line = reason
          final_output = [error_line | new_output]
          
          {:noreply,
           socket
           |> assign(:output_lines, final_output)
           |> assign(:current_input, "")
           |> assign(:command_history, new_history)
           |> assign(:history_index, -1)
          }
      end
    end
  end

  @impl true
  def handle_event("clear_terminal", _params, socket) do
    {:noreply, assign(socket, :output_lines, [])}
  end

  @impl true
  def handle_event("history_up", _params, socket) do
    history = socket.assigns.command_history
    current_index = socket.assigns.history_index
    
    if length(history) > 0 and current_index < length(history) - 1 do
      new_index = current_index + 1
      command = Enum.at(history, new_index)
      
      {:noreply,
       socket
       |> assign(:current_input, command)
       |> assign(:history_index, new_index)
      }
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("history_down", _params, socket) do
    current_index = socket.assigns.history_index
    
    if current_index > 0 do
      new_index = current_index - 1
      command = Enum.at(socket.assigns.command_history, new_index)
      
      {:noreply,
       socket
       |> assign(:current_input, command)
       |> assign(:history_index, new_index)
      }
    else
      {:noreply,
       socket
       |> assign(:current_input, "")
       |> assign(:history_index, -1)
      }
    end
  end

  @impl true
  def handle_event("update_input", %{"value" => value}, socket) do
    {:noreply, assign(socket, :current_input, value)}
  end
  
  @impl true
  def handle_event("update_input", %{"command" => command}, socket) do
    {:noreply, assign(socket, :current_input, command)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="bg-white shadow">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between items-center py-6">
            <div>
              <.link navigate={~p"/admin/nodes"} class="text-blue-600 hover:text-blue-800 text-sm font-medium">
                ← Back to Nodes
              </.link>
              <h1 class="text-3xl font-bold text-gray-900 mt-2">IEx Shell</h1>
              <p class="mt-1 text-sm text-gray-500">
                Interactive Elixir shell for 
                <span class="font-medium"><%= @node.name %>@<%= @node.host %></span>
                <span class={[
                  "ml-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium",
                  (if @connected, do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800")
                ]}>
                  <%= if @connected, do: "Connected", else: "Disconnected" %>
                </span>
              </p>
            </div>
            <div class="flex space-x-2">
              <button
                phx-click="clear_terminal"
                class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
              >
                Clear
              </button>
            </div>
          </div>
        </div>
      </div>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="bg-black rounded-lg shadow-lg overflow-hidden">
          <!-- Terminal Header -->
          <div class="bg-gray-800 px-4 py-2 flex items-center space-x-2">
            <div class="flex space-x-2">
              <div class="w-3 h-3 bg-red-500 rounded-full"></div>
              <div class="w-3 h-3 bg-yellow-500 rounded-full"></div>
              <div class="w-3 h-3 bg-green-500 rounded-full"></div>
            </div>
            <div class="flex-1 text-center">
              <span class="text-gray-300 text-sm font-mono">
                iex - <%= @node.name %>@<%= @node.host %>
              </span>
            </div>
          </div>

          <!-- Terminal Body -->
          <div class="p-4 h-96 overflow-y-auto font-mono text-sm" id="terminal-output">
            <!-- Welcome Message -->
            <%= if Enum.empty?(@output_lines) do %>
              <div class="text-green-400 mb-2">
                Erlang/OTP 26 [erts-14.0] [source] [64-bit] [smp:8:8] [ds:8:8:10] [async-threads:1]<br/>
                <br/>
                Interactive Elixir - connected to <%= @node.name %>@<%= @node.host %><br/>
              </div>
            <% end %>

            <!-- Output Lines -->
            <div class="space-y-1">
              <%= for line <- Enum.reverse(@output_lines) do %>
                <div class={[
                  (if String.starts_with?(line, "iex("), do: "text-blue-400", else: "text-gray-100"),
                  (if String.starts_with?(line, "** Error"), do: "text-red-400", else: "")
                ]}>
                  <%= line %>
                </div>
              <% end %>
            </div>

            <!-- Current Input Line -->
            <div class="flex items-center mt-2">
              <span class="text-blue-400 mr-2">iex(<%= @node.name %>)></span>
              <div class="flex-1">
                <form phx-submit="execute_command" class="flex">
                  <input
                    type="text"
                    name="command"
                    value={@current_input}
                    phx-change="update_input"
                    phx-value-name="current_input"
                    class="flex-1 bg-transparent text-gray-100 border-none outline-none font-mono"
                    placeholder="Enter Elixir code..."
                    autocomplete="off"
                    id="shell-input"
                    phx-hook="ShellInput"
                  />
                </form>
              </div>
            </div>
          </div>

          <!-- Terminal Footer -->
          <div class="bg-gray-800 px-4 py-2 border-t border-gray-700">
            <div class="flex justify-between items-center text-xs text-gray-400">
              <span>Enter: execute • ↑/↓: history • Tab: autocomplete • Ctrl+L: clear</span>
              <span>Session: <%= String.slice(@session_id, 0, 8) %></span>
            </div>
          </div>
        </div>

        <!-- Help Section -->
        <div class="mt-6 bg-white rounded-lg shadow p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Quick Reference</h3>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
            <div>
              <h4 class="font-medium text-gray-700 mb-2">Basic Commands</h4>
              <ul class="space-y-1 text-gray-600">
                <li><code class="bg-gray-100 px-1 rounded">1 + 1</code> - Simple arithmetic</li>
                <li><code class="bg-gray-100 px-1 rounded">:erlang.nodes()</code> - List connected nodes</li>
                <li><code class="bg-gray-100 px-1 rounded">Application.started_applications()</code> - Running apps</li>
                <li><code class="bg-gray-100 px-1 rounded">System.version()</code> - Elixir version</li>
              </ul>
            </div>
            <div>
              <h4 class="font-medium text-gray-700 mb-2">Process Management</h4>
              <ul class="space-y-1 text-gray-600">
                <li><code class="bg-gray-100 px-1 rounded">Process.list() |> length()</code> - Process count</li>
                <li><code class="bg-gray-100 px-1 rounded">:observer.start()</code> - Start observer (if available)</li>
                <li><code class="bg-gray-100 px-1 rounded">Supervisor.which_children(MySup)</code> - Child processes</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.encode64() |> binary_part(0, 16)
  end
end