defmodule ElixihubWeb.Admin.NodeLive.Index do
  use ElixihubWeb, :live_view

  alias Elixihub.Nodes
  alias Elixihub.Nodes.Node
  alias Elixihub.Authorization

  on_mount {ElixihubWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    
    unless Authorization.user_has_permission?(user, "admin:access") do
      {:ok, redirect(socket, to: ~p"/")}
    else
      # Ensure current node exists first
      Nodes.ensure_current_node()
      
      # Then refresh node statuses
      Nodes.refresh_node_statuses()
      
      {:ok, assign(socket, :nodes, Nodes.list_nodes())}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Manage Nodes")
    |> assign(:node, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Node")
    |> assign(:node, %Node{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Node")
    |> assign(:node, Nodes.get_node!(id))
  end

  @impl true
  def handle_info({ElixihubWeb.Admin.NodeLive.FormComponent, {:saved, _node}}, socket) do
    {:noreply, assign(socket, :nodes, Nodes.list_nodes())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    node = Nodes.get_node!(id)
    
    # Prevent deletion of current node
    if node.is_current do
      {:noreply, put_flash(socket, :error, "Cannot delete the current ElixiHub node")}
    else
      # Disconnect first if connected
      if node.status == "connected" do
        Nodes.disconnect_from_node(node)
      end
      
      {:ok, _} = Nodes.delete_node(node)
      {:noreply, 
       socket
       |> assign(:nodes, Nodes.list_nodes())
       |> put_flash(:info, "Node deleted successfully")
      }
    end
  end

  @impl true
  def handle_event("connect", %{"id" => id}, socket) do
    node = Nodes.get_node!(id)
    
    case Nodes.connect_to_node(node) do
      {:ok, _updated_node} ->
        # Refresh node statuses to ensure we have the latest data
        Nodes.refresh_node_statuses()
        
        {:noreply, 
         socket
         |> assign(:nodes, Nodes.list_nodes())
         |> put_flash(:info, "Successfully connected to #{node.name}")
        }
      
      {:error, reason} ->
        {:noreply, 
         socket
         |> assign(:nodes, Nodes.list_nodes())
         |> put_flash(:error, "Failed to connect: #{reason}")
        }
    end
  end

  @impl true
  def handle_event("disconnect", %{"id" => id}, socket) do
    node = Nodes.get_node!(id)
    
    case Nodes.disconnect_from_node(node) do
      {:ok, _updated_node} ->
        # Refresh node statuses to ensure we have the latest data
        Nodes.refresh_node_statuses()
        
        {:noreply, 
         socket
         |> assign(:nodes, Nodes.list_nodes())
         |> put_flash(:info, "Successfully disconnected from #{node.name}")
        }
      
      {:error, reason} ->
        {:noreply, 
         socket
         |> assign(:nodes, Nodes.list_nodes()) 
         |> put_flash(:error, "Failed to disconnect: #{reason}")
        }
    end
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    Nodes.refresh_node_statuses()
    
    {:noreply, 
     socket
     |> assign(:nodes, Nodes.list_nodes())
     |> put_flash(:info, "Node statuses refreshed")
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="bg-white shadow">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between items-center py-6">
            <div>
              <.link navigate={~p"/admin"} class="text-blue-600 hover:text-blue-800 text-sm font-medium">
                ← Back to Dashboard
              </.link>
              <h1 class="text-3xl font-bold text-gray-900 mt-2">Manage Nodes</h1>
              <p class="mt-1 text-sm text-gray-500">Connect to and manage remote Elixir nodes</p>
            </div>
            <div class="flex space-x-2">
              <button
                phx-click="refresh"
                class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
              >
                Refresh Status
              </button>
              <.link
                patch={~p"/admin/nodes/new"}
                class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
              >
                Add Node
              </.link>
            </div>
          </div>
        </div>
      </div>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
            <h3 class="text-lg leading-6 font-medium text-gray-900">
              Elixir Nodes
            </h3>
            <p class="mt-1 max-w-2xl text-sm text-gray-500">
              Manage connections to remote Elixir nodes for distributed operations
            </p>
            <%= if :erlang.node() == :nonode@nohost do %>
              <div class="mt-3 p-3 bg-yellow-50 border border-yellow-200 rounded-md">
                <div class="flex">
                  <div class="flex-shrink-0">
                    <svg class="h-5 w-5 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <h3 class="text-sm font-medium text-yellow-800">
                      Non-Distributed Mode
                    </h3>
                    <div class="mt-2 text-sm text-yellow-700">
                      <p>ElixiHub is running in non-distributed mode. To connect to remote nodes, restart with:</p>
                      <p class="mt-1 font-mono text-xs bg-yellow-100 px-2 py-1 rounded">
                        elixir --name elixihub@localhost -S mix phx.server
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
          
          <ul role="list" class="divide-y divide-gray-200" id="nodes">
            <li
              :for={node <- @nodes}
              id={"node-#{node.id}"}
              class="px-4 py-4 hover:bg-gray-50"
            >
              <div class="flex items-center justify-between">
                <div class="flex-1">
                  <div class="flex items-center">
                    <h4 class="text-lg font-medium text-gray-900"><%= node.name %>@<%= node.host %></h4>
                    <span class={[
                      "ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                      case node.status do
                        "connected" -> "bg-green-100 text-green-800"
                        "connecting" -> "bg-yellow-100 text-yellow-800"
                        "disconnected" -> "bg-gray-100 text-gray-800"
                        "error" -> "bg-red-100 text-red-800"
                      end
                    ]}>
                      <%= String.capitalize(node.status) %>
                    </span>
                    <%= if node.is_current do %>
                      <span class="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                        Current
                      </span>
                    <% end %>
                  </div>
                  <p class="text-sm text-gray-500 mt-1"><%= node.description %></p>
                  <div class="text-sm text-gray-600 mt-1">
                    Port: <%= node.port %> | Cookie: <code class="bg-gray-100 px-1 py-0.5 rounded text-xs"><%= String.slice(node.cookie, 0, 8) %>...</code>
                  </div>
                  <div class="text-xs text-gray-400 mt-1">
                    Added: <%= Calendar.strftime(node.inserted_at, "%B %d, %Y at %I:%M %p") %>
                  </div>
                </div>
                
                <div class="flex items-center space-x-2">
                  <%= if node.status == "connected" do %>
                    <.link
                      navigate={~p"/admin/nodes/#{node.id}/shell"}
                      class="text-purple-600 hover:text-purple-900 text-sm font-medium"
                    >
                      Shell
                    </.link>
                    
                    <button
                      phx-click="disconnect"
                      phx-value-id={node.id}
                      class="text-red-600 hover:text-red-900 text-sm font-medium"
                    >
                      Disconnect
                    </button>
                  <% else %>
                    <button
                      phx-click="connect"
                      phx-value-id={node.id}
                      class="text-green-600 hover:text-green-900 text-sm font-medium"
                    >
                      Connect
                    </button>
                  <% end %>
                  
                  <.link
                    patch={~p"/admin/nodes/#{node}/edit"}
                    class="text-blue-600 hover:text-blue-900 text-sm font-medium"
                  >
                    Edit
                  </.link>
                  
                  <%= unless node.is_current do %>
                    <button
                      phx-click="delete"
                      phx-value-id={node.id}
                      data-confirm="Are you sure you want to delete this node connection?"
                      class="text-red-600 hover:text-red-900 text-sm font-medium"
                    >
                      Delete
                    </button>
                  <% end %>
                </div>
              </div>
            </li>
          </ul>
          
          <div
            :if={Enum.empty?(@nodes)}
            class="text-center py-12"
          >
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h6a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h6a2 2 0 002-2v-4a2 2 0 00-2-2m8-12V4a2 2 0 012-2h4a2 2 0 012 2v4a2 2 0 01-2 2h-4a2 2 0 01-2-2V4z" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">No nodes found</h3>
            <p class="mt-1 text-sm text-gray-500">Get started by adding your first node connection.</p>
            <div class="mt-6">
              <.link
                patch={~p"/admin/nodes/new"}
                class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
              >
                Add Node
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="node-modal"
      show
      on_cancel={JS.patch(~p"/admin/nodes")}
    >
      <.live_component
        module={ElixihubWeb.Admin.NodeLive.FormComponent}
        id={@node.id || :new}
        title={@page_title}
        action={@live_action}
        node={@node}
        patch={~p"/admin/nodes"}
      />
    </.modal>
    """
  end
end