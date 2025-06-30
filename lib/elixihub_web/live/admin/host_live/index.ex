defmodule ElixihubWeb.Admin.HostLive.Index do
  use ElixihubWeb, :live_view

  alias Elixihub.Hosts
  alias Elixihub.Hosts.Host
  alias Elixihub.Authorization

  on_mount {ElixihubWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    
    unless Authorization.user_has_permission?(user, "admin:access") do
      {:ok, redirect(socket, to: ~p"/")}
    else
      {:ok, assign(socket, :hosts, Hosts.list_hosts())}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Manage Hosts")
    |> assign(:host, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Host")
    |> assign(:host, %Host{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Host")
    |> assign(:host, Hosts.get_host!(id))
  end

  @impl true
  def handle_info({ElixihubWeb.Admin.HostLive.FormComponent, {:saved, _host}}, socket) do
    {:noreply, assign(socket, :hosts, Hosts.list_hosts())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    host = Hosts.get_host!(id)
    {:ok, _} = Hosts.delete_host(host)

    {:noreply, 
     socket
     |> assign(:hosts, Hosts.list_hosts())
     |> put_flash(:info, "Host deleted successfully")
    }
  end

  @impl true
  def handle_event("test_connection", %{"id" => id}, socket) do
    host = Hosts.get_host!(id)
    
    socket = case Hosts.test_connection(host) do
      {:ok, message} ->
        put_flash(socket, :info, "#{host.name}: #{message}")
      
      {:error, reason} ->
        put_flash(socket, :error, "#{host.name}: Connection failed - #{reason}")
    end

    {:noreply, socket}
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
              <h1 class="text-3xl font-bold text-gray-900 mt-2">Manage Hosts</h1>
              <p class="mt-1 text-sm text-gray-500">Configure deployment hosts for your applications</p>
            </div>
            <div>
              <.link
                patch={~p"/admin/hosts/new"}
                class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
              >
                Add New Host
              </.link>
            </div>
          </div>
        </div>
      </div>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
            <h3 class="text-lg leading-6 font-medium text-gray-900">
              Deployment Hosts
            </h3>
            <p class="mt-1 max-w-2xl text-sm text-gray-500">
              Manage servers where applications can be deployed
            </p>
          </div>
          
          <ul role="list" class="divide-y divide-gray-200" id="hosts">
            <li
              :for={host <- @hosts}
              id={"host-#{host.id}"}
              class="px-4 py-4 hover:bg-gray-50"
            >
              <div class="flex items-center justify-between">
                <div class="flex-1">
                  <div class="flex items-center">
                    <h4 class="text-lg font-medium text-gray-900"><%= host.name %></h4>
                    <span class="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      Active
                    </span>
                  </div>
                  <p class="text-sm text-gray-500 mt-1"><%= host.description %></p>
                  <div class="text-sm text-gray-600 mt-1">
                    <div>IP Address: <span class="font-mono"><%= host.ip_address %></span></div>
                    <div>SSH Host: <span class="font-mono"><%= host.ssh_hostname %></span></div>
                    <div>SSH Port: <span class="font-mono"><%= host.ssh_port %></span></div>
                  </div>
                  <div class="text-xs text-gray-400 mt-1">
                    Added: <%= Calendar.strftime(host.inserted_at, "%B %d, %Y at %I:%M %p") %>
                  </div>
                </div>
                
                <div class="flex items-center space-x-2">
                  <button
                    phx-click="test_connection"
                    phx-value-id={host.id}
                    class="text-green-600 hover:text-green-900 text-sm font-medium"
                  >
                    Test Connection
                  </button>
                  
                  <.link
                    patch={~p"/admin/hosts/#{host}/edit"}
                    class="text-blue-600 hover:text-blue-900 text-sm font-medium"
                  >
                    Edit
                  </.link>
                  
                  <button
                    phx-click="delete"
                    phx-value-id={host.id}
                    data-confirm="Are you sure you want to delete this host? This action cannot be undone."
                    class="text-red-600 hover:text-red-900 text-sm font-medium"
                  >
                    Delete
                  </button>
                </div>
              </div>
            </li>
          </ul>
          
          <div
            :if={Enum.empty?(@hosts)}
            class="text-center py-12"
          >
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h6a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h6a2 2 0 002-2v-4a2 2 0 00-2-2m8-8v8m0-8a2 2 0 012-2h2a2 2 0 012 2v8a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">No hosts configured</h3>
            <p class="mt-1 text-sm text-gray-500">Get started by adding your first deployment host.</p>
            <div class="mt-6">
              <.link
                patch={~p"/admin/hosts/new"}
                class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
              >
                Add Host
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="host-modal"
      show
      on_cancel={JS.patch(~p"/admin/hosts")}
    >
      <.live_component
        module={ElixihubWeb.Admin.HostLive.FormComponent}
        id={@host.id || :new}
        title={@page_title}
        action={@live_action}
        host={@host}
        patch={~p"/admin/hosts"}
      />
    </.modal>
    """
  end
end