defmodule ElixihubWeb.Admin.PermissionLive.Index do
  use ElixihubWeb, :live_view

  alias Elixihub.Authorization
  alias Elixihub.Authorization.Permission

  on_mount {ElixihubWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    
    unless Authorization.user_has_permission?(user, "admin:access") do
      {:ok, redirect(socket, to: ~p"/")}
    else
      {:ok, assign(socket, :permissions, Authorization.list_permissions())}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Manage Permissions")
    |> assign(:permission, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Permission")
    |> assign(:permission, %Permission{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Permission")
    |> assign(:permission, Authorization.get_permission!(id))
  end

  @impl true
  def handle_info({ElixihubWeb.Admin.PermissionLive.FormComponent, {:saved, _permission}}, socket) do
    {:noreply, assign(socket, :permissions, Authorization.list_permissions())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    permission = Authorization.get_permission!(id)
    
    # Prevent deletion of essential permissions
    if permission.name in ["admin:access", "user:access", "app:manage"] do
      {:noreply, put_flash(socket, :error, "Cannot delete essential system permissions")}
    else
      {:ok, _} = Authorization.delete_permission(permission)
      {:noreply, 
       socket
       |> assign(:permissions, Authorization.list_permissions())
       |> put_flash(:info, "Permission deleted successfully")
      }
    end
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
              <h1 class="text-3xl font-bold text-gray-900 mt-2">Manage Permissions</h1>
              <p class="mt-1 text-sm text-gray-500">Create and configure system permissions</p>
            </div>
            <div>
              <.link
                patch={~p"/admin/permissions/new"}
                class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
              >
                New Permission
              </.link>
            </div>
          </div>
        </div>
      </div>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
            <h3 class="text-lg leading-6 font-medium text-gray-900">
              All Permissions
            </h3>
            <p class="mt-1 max-w-2xl text-sm text-gray-500">
              Manage system permissions that can be assigned to roles
            </p>
          </div>
          
          <ul role="list" class="divide-y divide-gray-200" id="permissions">
            <li
              :for={permission <- @permissions}
              id={"permission-#{permission.id}"}
              class="px-4 py-4 hover:bg-gray-50"
            >
              <div class="flex items-center justify-between">
                <div class="flex-1">
                  <div class="flex items-center">
                    <h4 class="text-lg font-medium text-gray-900"><%= permission.name %></h4>
                    <%= if permission.name in ["admin:access", "user:access", "app:manage"] do %>
                      <span class="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                        System Permission
                      </span>
                    <% end %>
                  </div>
                  <p class="text-sm text-gray-500 mt-1"><%= permission.description %></p>
                  <div class="text-xs text-gray-400 mt-1">
                    Created: <%= Calendar.strftime(permission.inserted_at, "%B %d, %Y at %I:%M %p") %>
                  </div>
                </div>
                
                <div class="flex items-center space-x-2">
                  <.link
                    patch={~p"/admin/permissions/#{permission}/edit"}
                    class="text-green-600 hover:text-green-900 text-sm font-medium"
                  >
                    Edit
                  </.link>
                  
                  <%= unless permission.name in ["admin:access", "user:access", "app:manage"] do %>
                    <button
                      phx-click="delete"
                      phx-value-id={permission.id}
                      data-confirm="Are you sure you want to delete this permission? This will remove it from all roles."
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
            :if={Enum.empty?(@permissions)}
            class="text-center py-12"
          >
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">No permissions found</h3>
            <p class="mt-1 text-sm text-gray-500">Get started by creating a new permission.</p>
            <div class="mt-6">
              <.link
                patch={~p"/admin/permissions/new"}
                class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
              >
                Create Permission
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="permission-modal"
      show
      on_cancel={JS.patch(~p"/admin/permissions")}
    >
      <.live_component
        module={ElixihubWeb.Admin.PermissionLive.FormComponent}
        id={@permission.id || :new}
        title={@page_title}
        action={@live_action}
        permission={@permission}
        patch={~p"/admin/permissions"}
      />
    </.modal>
    """
  end
end