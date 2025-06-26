defmodule ElixihubWeb.Admin.UserLive.Roles do
  use ElixihubWeb, :live_view

  alias Elixihub.Accounts
  alias Elixihub.Authorization

  on_mount {ElixihubWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(%{"id" => user_id}, _session, socket) do
    current_user = socket.assigns.current_user
    
    unless Authorization.user_has_permission?(current_user, "admin:access") do
      {:ok, redirect(socket, to: ~p"/")}
    else
      user = Accounts.get_user!(user_id) |> Elixihub.Repo.preload(:roles)
      all_roles = Authorization.list_roles()
      
      {:ok,
       socket
       |> assign(:page_title, "Manage User Roles")
       |> assign(:user, user)
       |> assign(:all_roles, all_roles)
       |> assign(:user_role_ids, Enum.map(user.roles, & &1.id))
      }
    end
  end

  @impl true
  def handle_event("toggle_role", %{"role_id" => role_id}, socket) do
    role_id = String.to_integer(role_id)
    user = socket.assigns.user
    role = Enum.find(socket.assigns.all_roles, &(&1.id == role_id))
    
    user_role_ids = socket.assigns.user_role_ids
    
    {new_user_role_ids, message} = 
      if role_id in user_role_ids do
        # Remove role
        case Authorization.remove_role_from_user(user, role) do
          {:ok, _} -> 
            {List.delete(user_role_ids, role_id), "Role '#{role.name}' removed successfully"}
          {:error, _} -> 
            {user_role_ids, "Failed to remove role"}
        end
      else
        # Add role
        case Authorization.assign_role_to_user(user, role) do
          {:ok, _} -> 
            {[role_id | user_role_ids], "Role '#{role.name}' assigned successfully"}
          {:error, _} -> 
            {user_role_ids, "Failed to assign role"}
        end
      end

    {:noreply,
     socket
     |> assign(:user_role_ids, new_user_role_ids)
     |> put_flash(:info, message)
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
              <.link navigate={~p"/admin/users"} class="text-blue-600 hover:text-blue-800 text-sm font-medium">
                ← Back to Users
              </.link>
              <h1 class="text-3xl font-bold text-gray-900 mt-2">Manage User Roles</h1>
              <p class="mt-1 text-sm text-gray-500">
                Managing roles for: <span class="font-medium"><%= @user.email %></span>
              </p>
            </div>
          </div>
        </div>
      </div>

      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-medium text-gray-900">Available Roles</h3>
            <p class="mt-1 text-sm text-gray-500">
              Select the roles you want to assign to this user
            </p>
          </div>
          
          <div class="p-6">
            <div class="space-y-4">
              <div
                :for={role <- @all_roles}
                class="flex items-center justify-between p-4 border border-gray-200 rounded-lg hover:bg-gray-50"
              >
                <div class="flex items-center">
                  <input
                    type="checkbox"
                    id={"role_#{role.id}"}
                    checked={role.id in @user_role_ids}
                    phx-click="toggle_role"
                    phx-value-role_id={role.id}
                    class="h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                  />
                  <div class="ml-3">
                    <label for={"role_#{role.id}"} class="text-sm font-medium text-gray-900 cursor-pointer">
                      <%= role.name %>
                    </label>
                    <p class="text-sm text-gray-500"><%= role.description %></p>
                  </div>
                </div>
                
                <div class="flex items-center">
                  <%= if role.id in @user_role_ids do %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      Assigned
                    </span>
                  <% else %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                      Not Assigned
                    </span>
                  <% end %>
                </div>
              </div>
            </div>
            
            <%= if Enum.empty?(@all_roles) do %>
              <div class="text-center py-8">
                <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                </svg>
                <h3 class="mt-2 text-sm font-medium text-gray-900">No roles available</h3>
                <p class="mt-1 text-sm text-gray-500">Create some roles first to assign to users.</p>
                <div class="mt-6">
                  <.link
                    navigate={~p"/admin/roles"}
                    class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
                  >
                    Manage Roles
                  </.link>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Current Assignments Summary -->
        <div class="mt-6 bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-medium text-gray-900">Current Role Assignments</h3>
          </div>
          <div class="p-6">
            <%= if Enum.empty?(@user_role_ids) do %>
              <p class="text-sm text-gray-500">This user has no roles assigned.</p>
            <% else %>
              <div class="space-y-2">
                <div
                  :for={role <- @all_roles}
                  :if={role.id in @user_role_ids}
                  class="flex items-center justify-between p-3 bg-green-50 border border-green-200 rounded-lg"
                >
                  <div>
                    <p class="text-sm font-medium text-green-900"><%= role.name %></p>
                    <p class="text-sm text-green-700"><%= role.description %></p>
                  </div>
                  <button
                    phx-click="toggle_role"
                    phx-value-role_id={role.id}
                    class="text-green-600 hover:text-green-800 text-sm"
                  >
                    Remove
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end