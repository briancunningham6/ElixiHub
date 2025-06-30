defmodule ElixihubWeb.Admin.HostLive.Shell do
  use ElixihubWeb, :live_view

  alias Elixihub.Hosts
  alias Elixihub.Authorization

  on_mount {ElixihubWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(%{"host_id" => host_id}, _session, socket) do
    user = socket.assigns.current_user
    
    unless Authorization.user_has_permission?(user, "admin:access") do
      {:ok, redirect(socket, to: ~p"/")}
    else
      host = Hosts.get_host!(host_id)
      
      socket =
        socket
        |> assign(:host, host)
        |> assign(:connected, false)
        |> assign(:connection_error, nil)
        |> assign(:shell_output, [])
        |> assign(:ssh_connection, nil)
        |> assign(:ssh_channel, nil)

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("connect_shell", _params, socket) do
    host = socket.assigns.host
    
    case establish_ssh_connection(host) do
      {:ok, {connection, channel}} ->
        # Send initial welcome message
        send(self(), {:shell_data, "Connected to #{host.name} (#{host.ip_address})\r\n"})
        
        socket = 
          socket
          |> assign(:connected, true)
          |> assign(:connection_error, nil)
          |> assign(:ssh_connection, connection)
          |> assign(:ssh_channel, channel)
          |> assign(:shell_output, [])

        {:noreply, socket}
      
      {:error, reason} ->
        socket = 
          socket
          |> assign(:connected, false)
          |> assign(:connection_error, "Connection failed: #{reason}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("disconnect_shell", _params, socket) do
    disconnect_ssh(socket)
    
    socket = 
      socket
      |> assign(:connected, false)
      |> assign(:ssh_connection, nil)
      |> assign(:ssh_channel, nil)
      |> assign(:shell_output, [])

    {:noreply, socket}
  end

  @impl true
  def handle_event("shell_input", %{"data" => data}, socket) do
    if socket.assigns.connected do
      case send_to_shell(socket, data) do
        :ok -> 
          {:noreply, socket}
        {:error, _reason} ->
          # Connection lost, disconnect
          socket = 
            socket
            |> assign(:connected, false)
            |> assign(:connection_error, "Connection lost")
            |> put_flash(:error, "SSH connection lost")

          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("shell_input_form", %{"command" => command}, socket) do
    if socket.assigns.connected do
      # Add newline to command
      command_with_newline = command <> "\n"
      
      case send_to_shell(socket, command_with_newline) do
        :ok -> 
          {:noreply, socket}
        {:error, _reason} ->
          # Connection lost, disconnect
          socket = 
            socket
            |> assign(:connected, false)
            |> assign(:connection_error, "Connection lost")
            |> put_flash(:error, "SSH connection lost")

          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("insert_command", %{"command" => command}, socket) do
    # Insert command text into the input field using JavaScript
    socket = push_event(socket, "insert_text", %{text: command})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:shell_data, data}, socket) do
    # Clean ANSI escape sequences from the output
    cleaned_data = clean_ansi_sequences(data)
    
    new_output = socket.assigns.shell_output ++ [cleaned_data]
    
    # Keep only last 1000 lines to prevent memory issues
    trimmed_output = if length(new_output) > 1000 do
      Enum.take(new_output, -1000)
    else
      new_output
    end

    socket = 
      socket
      |> assign(:shell_output, trimmed_output)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:ssh_cm, connection, {:data, channel, 0, data}}, socket) do
    if socket.assigns.ssh_connection == connection and socket.assigns.ssh_channel == channel do
      send(self(), {:shell_data, to_string(data)})
    end
    {:noreply, socket}
  end

  @impl true
  def handle_info({:ssh_cm, connection, {:data, channel, 1, data}}, socket) do
    # Handle stderr data
    if socket.assigns.ssh_connection == connection and socket.assigns.ssh_channel == channel do
      send(self(), {:shell_data, to_string(data)})
    end
    {:noreply, socket}
  end

  @impl true
  def handle_info({:ssh_cm, connection, {:closed, channel}}, socket) do
    if socket.assigns.ssh_connection == connection and socket.assigns.ssh_channel == channel do
      socket = 
        socket
        |> assign(:connected, false)
        |> assign(:connection_error, "Connection closed by remote host")
        |> put_flash(:error, "SSH connection closed")

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Ignore other SSH messages
  @impl true
  def handle_info({:ssh_cm, _connection, _message}, socket) do
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    disconnect_ssh(socket)
    :ok
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-white">
      <div class="bg-gray-800 shadow">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between items-center py-4">
            <div class="flex items-center">
              <.link navigate={~p"/admin/hosts"} class="text-blue-400 hover:text-blue-300 text-sm font-medium mr-4">
                ← Back to Hosts
              </.link>
              <h1 class="text-xl font-bold text-white">SSH Shell</h1>
              <span class="ml-2 text-sm text-gray-300">
                <%= @host.name %> (<%= @host.ip_address %>)
              </span>
            </div>
            <div class="flex items-center space-x-3">
              <div class="flex items-center">
                <div class={[
                  "w-3 h-3 rounded-full mr-2",
                  if @connected do
                    "bg-green-400"
                  else
                    "bg-red-400"
                  end
                ]}>
                </div>
                <span class="text-sm">
                  <%= if @connected, do: "Connected", else: "Disconnected" %>
                </span>
              </div>
              
              <%= if @connected do %>
                <button
                  phx-click="disconnect_shell"
                  class="inline-flex items-center px-3 py-2 border border-red-600 text-sm font-medium rounded-md text-red-400 bg-transparent hover:bg-red-600 hover:text-white"
                >
                  <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                  Disconnect
                </button>
              <% else %>
                <button
                  phx-click="connect_shell"
                  class="inline-flex items-center px-3 py-2 border border-green-600 text-sm font-medium rounded-md text-green-400 bg-transparent hover:bg-green-600 hover:text-white"
                >
                  <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.111 16.404a5.5 5.5 0 017.778 0M12 20h.01m-7.08-7.071c3.904-3.905 10.236-3.905 14.141 0M1.394 9.393c5.857-5.857 15.355-5.857 21.213 0" />
                  </svg>
                  Connect
                </button>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
        <%= if @connection_error do %>
          <div class="mb-4 p-4 bg-red-900 border border-red-700 rounded-md">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                </svg>
              </div>
              <div class="ml-3">
                <h3 class="text-sm font-medium text-red-400">Connection Error</h3>
                <div class="mt-2 text-sm text-red-300">
                  <p><%= @connection_error %></p>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <div class="bg-black rounded-lg border border-gray-700 overflow-hidden">
          <div class="bg-gray-800 px-4 py-2 border-b border-gray-700">
            <div class="flex items-center">
              <div class="flex space-x-2">
                <div class="w-3 h-3 bg-red-500 rounded-full"></div>
                <div class="w-3 h-3 bg-yellow-500 rounded-full"></div>
                <div class="w-3 h-3 bg-green-500 rounded-full"></div>
              </div>
              <div class="ml-4 text-sm text-gray-300">
                Terminal - <%= @host.name %>
              </div>
            </div>
          </div>
          
          <div 
            id="terminal-container" 
            class="relative"
            phx-hook="Terminal"
            data-connected={@connected}
          >
            <%= if not @connected do %>
              <div class="p-8 text-center text-gray-500">
                <svg class="w-16 h-16 mx-auto mb-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v14a2 2 0 002 2z" />
                </svg>
                <p class="text-lg mb-2">Terminal Not Connected</p>
                <p class="text-sm">Click "Connect" to establish an SSH connection to <%= @host.name %></p>
              </div>
            <% else %>
              <!-- Simple Terminal Interface -->
              <div class="h-96 bg-black text-white font-mono text-sm flex flex-col">
                <!-- Terminal Output -->
                <div class="flex-1 p-4 overflow-y-auto whitespace-pre-wrap" id="terminal-output">
                  <%= for {output, index} <- Enum.with_index(@shell_output) do %>
                    <div id={"output-#{index}"}><%= output %></div>
                  <% end %>
                </div>
                
                <!-- Terminal Input -->
                <div class="border-t border-gray-700 p-2 flex items-center">
                  <span class="text-green-400 mr-2">$</span>
                  <form phx-submit="shell_input_form" class="flex-1">
                    <input 
                      type="text" 
                      name="command" 
                      value=""
                      placeholder="Type your command and press Enter..."
                      class="w-full bg-transparent border-none outline-none text-white"
                      autocomplete="off"
                      phx-hook="TerminalInput"
                      id="terminal-input"
                    />
                  </form>
                </div>
              </div>
              
              <div class="text-xs text-gray-500 p-2">
                Connection status: Connected | Output lines: <%= length(@shell_output) %>
              </div>
            <% end %>
          </div>
        </div>

        <%= if @connected do %>
          <div class="mt-4 p-4 bg-gray-800 rounded-lg border border-gray-700">
            <h3 class="text-sm font-medium text-gray-300 mb-2">Quick Commands</h3>
            <div class="flex flex-wrap gap-2">
              <button 
                phx-click="insert_command" 
                phx-value-command="ls -la"
                class="px-3 py-1 bg-gray-700 hover:bg-gray-600 rounded text-sm text-gray-300"
              >
                ls -la
              </button>
              <button 
                phx-click="insert_command" 
                phx-value-command="pwd"
                class="px-3 py-1 bg-gray-700 hover:bg-gray-600 rounded text-sm text-gray-300"
              >
                pwd
              </button>
              <button 
                phx-click="insert_command" 
                phx-value-command="top"
                class="px-3 py-1 bg-gray-700 hover:bg-gray-600 rounded text-sm text-gray-300"
              >
                top
              </button>
              <button 
                phx-click="insert_command" 
                phx-value-command="df -h"
                class="px-3 py-1 bg-gray-700 hover:bg-gray-600 rounded text-sm text-gray-300"
              >
                df -h
              </button>
              <button 
                phx-click="insert_command" 
                phx-value-command="systemctl status"
                class="px-3 py-1 bg-gray-700 hover:bg-gray-600 rounded text-sm text-gray-300"
              >
                systemctl status
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Private functions

  defp establish_ssh_connection(host) do
    ssh_config = Hosts.host_to_ssh_config(host)
    
    case Elixihub.Deployment.SSHClient.connect(ssh_config) do
      {:ok, connection} ->
        case :ssh_connection.session_channel(connection, 30000) do
          {:ok, channel} ->
            # Request a PTY for interactive shell
            pty_req = :ssh_connection.ptty_alloc(connection, channel, [
              {:"term", 'xterm-256color'},
              {:width, 80},
              {:height, 24},
              {:pixel_width, 0},
              {:pixel_height, 0},
              {:modes, []}
            ])
            
            case pty_req do
              :success ->
                # Start shell
                case :ssh_connection.shell(connection, channel) do
                  :ok ->
                    {:ok, {connection, channel}}
                  :failure ->
                    :ssh_connection.close(connection, channel)
                    Elixihub.Deployment.SSHClient.disconnect(connection)
                    {:error, "Failed to start shell"}
                  {:error, reason} ->
                    :ssh_connection.close(connection, channel)
                    Elixihub.Deployment.SSHClient.disconnect(connection)
                    {:error, "Failed to start shell: #{inspect(reason)}"}
                end
              :failure ->
                :ssh_connection.close(connection, channel)
                Elixihub.Deployment.SSHClient.disconnect(connection)
                {:error, "Failed to allocate PTY"}
            end
          
          {:error, reason} ->
            Elixihub.Deployment.SSHClient.disconnect(connection)
            {:error, "Failed to open channel: #{inspect(reason)}"}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp send_to_shell(socket, data) do
    connection = socket.assigns.ssh_connection
    channel = socket.assigns.ssh_channel
    
    if connection && channel do
      case :ssh_connection.send(connection, channel, data) do
        :ok -> :ok
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "No active connection"}
    end
  end

  defp disconnect_ssh(socket) do
    if socket.assigns.ssh_connection && socket.assigns.ssh_channel do
      :ssh_connection.close(socket.assigns.ssh_connection, socket.assigns.ssh_channel)
      Elixihub.Deployment.SSHClient.disconnect(socket.assigns.ssh_connection)
    end
  end

  defp clean_ansi_sequences(data) do
    data
    # Remove ANSI escape sequences (ESC[...m for colors, ESC[...H for cursor, etc.)
    |> String.replace(~r/\e\[[0-9;]*[A-Za-z]/, "")
    # Remove OSC sequences (like window title setting: ESC]0;title\a or ESC]0;title\007)
    |> String.replace(~r/\e\][0-9]*;[^\a\007]*[\a\007]/, "")
    # Remove other control sequences
    |> String.replace(~r/\e\([AB]/, "")
    # Remove backspace and other control characters (but keep \r, \n, \t)
    |> String.replace(~r/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "")
  end
end