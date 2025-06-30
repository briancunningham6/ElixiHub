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

  defp apply_action(socket, :restart_confirm, %{"id" => id}) do
    socket
    |> assign(:page_title, "Restart Host")
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
  def handle_event("restart_host", %{"id" => id}, socket) do
    host = Hosts.get_host!(id)
    
    # Start restart process asynchronously
    Task.start(fn ->
      case Hosts.restart_host(host) do
        {:ok, message} ->
          send(self(), {:restart_complete, host.id, :success, message})
        {:error, reason} ->
          send(self(), {:restart_complete, host.id, :error, reason})
      end
    end)
    
    socket = 
      socket
      |> put_flash(:info, "Restart initiated for #{host.name}. This may take a few moments...")
      |> push_patch(to: ~p"/admin/hosts")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:restart_complete, host_id, status, result}, socket) do
    host = Hosts.get_host!(host_id)
    
    socket = case status do
      :success ->
        put_flash(socket, :info, "#{host.name}: #{result}")
      :error ->
        put_flash(socket, :error, "#{host.name}: Restart failed - #{result}")
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
                    navigate={~p"/admin/hosts/#{host}/shell"}
                    class="text-purple-600 hover:text-purple-900 text-sm font-medium"
                  >
                    Launch Shell
                  </.link>
                  
                  <.link
                    patch={~p"/admin/hosts/#{host}/restart"}
                    class="text-orange-600 hover:text-orange-900 text-sm font-medium"
                  >
                    Restart
                  </.link>
                  
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

    <.modal
      :if={@live_action == :restart_confirm}
      id="restart-confirm-modal"
      show
      on_cancel={JS.patch(~p"/admin/hosts")}
    >
      <div class="sm:flex sm:items-start">
        <div class="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-red-100 sm:mx-0 sm:h-10 sm:w-10">
          <svg class="h-6 w-6 text-red-600" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
          </svg>
        </div>
        <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left">
          <h3 class="text-lg leading-6 font-medium text-gray-900">
            Restart Host
          </h3>
          <div class="mt-2">
            <p class="text-sm text-gray-500">
              Are you sure you want to restart <strong><%= @host.name %></strong> (<%= @host.ip_address %>)?
            </p>
            <div class="mt-3 p-3 bg-yellow-50 border border-yellow-200 rounded-md">
              <div class="flex">
                <div class="flex-shrink-0">
                  <svg class="h-5 w-5 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                  </svg>
                </div>
                <div class="ml-3">
                  <h3 class="text-sm font-medium text-yellow-800">
                    Warning
                  </h3>
                  <div class="mt-2 text-sm text-yellow-700">
                    <ul class="list-disc list-inside space-y-1">
                      <li>This will reboot the entire host system</li>
                      <li>All running applications will be interrupted</li>
                      <li>The host will be temporarily unavailable</li>
                      <li>This action cannot be undone</li>
                    </ul>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
        <button
          type="button"
          phx-click="restart_host"
          phx-value-id={@host.id}
          class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-red-600 text-base font-medium text-white hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 sm:ml-3 sm:w-auto sm:text-sm"
        >
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
          Restart Host
        </button>
        <button
          type="button"
          phx-click={JS.patch(~p"/admin/hosts")}
          class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:w-auto sm:text-sm"
        >
          Cancel
        </button>
      </div>
    </.modal>
    """
  end
end