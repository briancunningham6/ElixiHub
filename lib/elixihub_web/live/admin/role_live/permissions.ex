defmodule ElixihubWeb.Admin.RoleLive.Permissions do
  use ElixihubWeb, :live_view

  alias Elixihub.Authorization

  on_mount {ElixihubWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(%{"id" => role_id}, _session, socket) do
    user = socket.assigns.current_user
    
    unless Authorization.user_has_permission?(user, "admin:access") do
      {:ok, redirect(socket, to: ~p"/")}
    else
      role = Authorization.get_role!(role_id) |> Elixihub.Repo.preload(:permissions)
      all_permissions = Authorization.list_permissions()
      
      {:ok, 
       socket
       |> assign(:role, role)
       |> assign(:all_permissions, all_permissions)
       |> assign(:page_title, "Manage Permissions for #{role.name}")
      }
    end
  end

  @impl true
  def handle_event("assign_permission", %{"permission_id" => permission_id}, socket) do
    permission = Authorization.get_permission!(permission_id)
    role = socket.assigns.role
    
    case Authorization.assign_permission_to_role(role, permission) do
      {:ok, updated_role} ->
        updated_role = Elixihub.Repo.preload(updated_role, :permissions, force: true)
        
        {:noreply, 
         socket
         |> assign(:role, updated_role)
         |> put_flash(:info, "Permission assigned successfully")
        }
      
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to assign permission")}
    end
  end

  @impl true
  def handle_event("remove_permission", %{"permission_id" => permission_id}, socket) do
    permission = Authorization.get_permission!(permission_id)
    role = socket.assigns.role
    
    case Authorization.remove_permission_from_role(role, permission) do
      {:ok, updated_role} ->
        updated_role = Elixihub.Repo.preload(updated_role, :permissions, force: true)
        
        {:noreply, 
         socket
         |> assign(:role, updated_role)
         |> put_flash(:info, "Permission removed successfully")
        }
      
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to remove permission")}
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
              <.link navigate={~p"/admin/roles"} class="text-blue-600 hover:text-blue-800 text-sm font-medium">
                ← Back to Roles
              </.link>
              <h1 class="text-3xl font-bold text-gray-900 mt-2">Manage Permissions</h1>
              <p class="mt-1 text-sm text-gray-500">Configure permissions for the "<%= @role.name %>" role</p>
            </div>
          </div>
        </div>
      </div>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Assigned Permissions -->
          <div class="bg-white shadow overflow-hidden sm:rounded-lg">
            <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
              <h3 class="text-lg leading-6 font-medium text-gray-900">
                Assigned Permissions
              </h3>
              <p class="mt-1 max-w-2xl text-sm text-gray-500">
                Permissions currently assigned to this role
              </p>
            </div>
            
            <div class="px-4 py-5 sm:px-6">
              <%= if Enum.empty?(@role.permissions) do %>
                <div class="text-center py-8">
                  <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  <h3 class="mt-2 text-sm font-medium text-gray-900">No permissions assigned</h3>
                  <p class="mt-1 text-sm text-gray-500">Assign permissions from the available list.</p>
                </div>
              <% else %>
                <ul class="divide-y divide-gray-200">
                  <li :for={permission <- @role.permissions} class="py-4 flex items-center justify-between">
                    <div class="flex-1">
                      <div class="text-sm font-medium text-gray-900"><%= permission.name %></div>
                      <div class="text-sm text-gray-500"><%= permission.description %></div>
                    </div>
                    <button
                      phx-click="remove_permission"
                      phx-value-permission_id={permission.id}
                      data-confirm="Are you sure you want to remove this permission from the role?"
                      class="ml-4 text-red-600 hover:text-red-900 text-sm font-medium"
                    >
                      Remove
                    </button>
                  </li>
                </ul>
              <% end %>
            </div>
          </div>

          <!-- Available Permissions -->
          <div class="bg-white shadow overflow-hidden sm:rounded-lg">
            <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
              <h3 class="text-lg leading-6 font-medium text-gray-900">
                Available Permissions
              </h3>
              <p class="mt-1 max-w-2xl text-sm text-gray-500">
                Permissions that can be assigned to this role
              </p>
            </div>
            
            <div class="px-4 py-5 sm:px-6">
              <% assigned_permission_ids = Enum.map(@role.permissions, & &1.id) %>
              <% available_permissions = Enum.reject(@all_permissions, &(&1.id in assigned_permission_ids)) %>
              
              <%= if Enum.empty?(available_permissions) do %>
                <div class="text-center py-8">
                  <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  <h3 class="mt-2 text-sm font-medium text-gray-900">All permissions assigned</h3>
                  <p class="mt-1 text-sm text-gray-500">This role has all available permissions.</p>
                </div>
              <% else %>
                <ul class="divide-y divide-gray-200">
                  <li :for={permission <- available_permissions} class="py-4 flex items-center justify-between">
                    <div class="flex-1">
                      <div class="text-sm font-medium text-gray-900"><%= permission.name %></div>
                      <div class="text-sm text-gray-500"><%= permission.description %></div>
                    </div>
                    <button
                      phx-click="assign_permission"
                      phx-value-permission_id={permission.id}
                      class="ml-4 text-blue-600 hover:text-blue-900 text-sm font-medium"
                    >
                      Assign
                    </button>
                  </li>
                </ul>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end