defmodule ElixihubWeb.Admin.UserLive.Roles do
  use ElixihubWeb, :live_view

  alias Elixihub.Accounts
  alias Elixihub.Authorization
  alias Elixihub.Apps

  on_mount {ElixihubWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(%{"id" => user_id}, _session, socket) do
    current_user = socket.assigns.current_user
    
    unless Authorization.user_has_permission?(current_user, "admin:access") do
      {:ok, redirect(socket, to: ~p"/")}
    else
      user = Accounts.get_user!(user_id) |> Elixihub.Repo.preload([:roles, user_roles: [:role, :app_role]])
      all_roles = Authorization.list_roles()
      all_apps = Apps.list_apps() |> Elixihub.Repo.preload(:app_roles)
      
      # Get current assignments
      system_role_ids = Enum.filter(user.user_roles, &(&1.role_id != nil)) |> Enum.map(& &1.role_id)
      app_role_ids = Enum.filter(user.user_roles, &(&1.app_role_id != nil)) |> Enum.map(& &1.app_role_id)
      
      {:ok,
       socket
       |> assign(:page_title, "Manage User Roles")
       |> assign(:user, user)
       |> assign(:all_roles, all_roles)
       |> assign(:all_apps, all_apps)
       |> assign(:system_role_ids, system_role_ids)
       |> assign(:app_role_ids, app_role_ids)
      }
    end
  end

  @impl true
  def handle_event("toggle_system_role", %{"role_id" => role_id}, socket) do
    role_id = String.to_integer(role_id)
    user = socket.assigns.user
    role = Enum.find(socket.assigns.all_roles, &(&1.id == role_id))
    
    system_role_ids = socket.assigns.system_role_ids
    
    {new_system_role_ids, message} = 
      if role_id in system_role_ids do
        # Remove role
        case Authorization.remove_role_from_user(user, role) do
          {:ok, _} -> 
            {List.delete(system_role_ids, role_id), "System role '#{role.name}' removed successfully"}
          {:error, _} -> 
            {system_role_ids, "Failed to remove system role"}
        end
      else
        # Add role
        case Authorization.assign_role_to_user(user, role) do
          {:ok, _} -> 
            {[role_id | system_role_ids], "System role '#{role.name}' assigned successfully"}
          {:error, _} -> 
            {system_role_ids, "Failed to assign system role"}
        end
      end

    {:noreply,
     socket
     |> assign(:system_role_ids, new_system_role_ids)
     |> put_flash(:info, message)
    }
  end

  @impl true
  def handle_event("toggle_app_role", %{"app_role_id" => app_role_id}, socket) do
    app_role_id = String.to_integer(app_role_id)
    user = socket.assigns.user
    app_role = find_app_role_by_id(socket.assigns.all_apps, app_role_id)
    
    app_role_ids = socket.assigns.app_role_ids
    
    {new_app_role_ids, message} = 
      if app_role_id in app_role_ids do
        # Remove app role
        case Authorization.remove_app_role_from_user(user, app_role) do
          {:ok, _} -> 
            {List.delete(app_role_ids, app_role_id), "App role '#{app_role.name}' removed successfully"}
          {:error, _} -> 
            {app_role_ids, "Failed to remove app role"}
        end
      else
        # Add app role
        case Authorization.assign_app_role_to_user(user, app_role) do
          {:ok, _} -> 
            {[app_role_id | app_role_ids], "App role '#{app_role.name}' assigned successfully"}
          {:error, _} -> 
            {app_role_ids, "Failed to assign app role"}
        end
      end

    {:noreply,
     socket
     |> assign(:app_role_ids, new_app_role_ids)
     |> put_flash(:info, message)
    }
  end

  defp find_app_role_by_id(apps, app_role_id) do
    Enum.find_value(apps, fn app ->
      Enum.find(app.app_roles, &(&1.id == app_role_id))
    end)
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

      <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
        <!-- System Roles -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-medium text-gray-900">System Roles</h3>
            <p class="mt-1 text-sm text-gray-500">
              Global roles that apply across the entire ElixiHub system
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
                    id={"system_role_#{role.id}"}
                    checked={role.id in @system_role_ids}
                    phx-click="toggle_system_role"
                    phx-value-role_id={role.id}
                    class="h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                  />
                  <div class="ml-3">
                    <label for={"system_role_#{role.id}"} class="text-sm font-medium text-gray-900 cursor-pointer">
                      <%= role.name %>
                    </label>
                    <p class="text-sm text-gray-500"><%= role.description %></p>
                  </div>
                </div>
                
                <div class="flex items-center">
                  <%= if role.id in @system_role_ids do %>
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
                <h3 class="mt-2 text-sm font-medium text-gray-900">No system roles available</h3>
                <p class="mt-1 text-sm text-gray-500">Create some system roles first.</p>
                <div class="mt-6">
                  <.link
                    navigate={~p"/admin/roles"}
                    class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
                  >
                    Manage System Roles
                  </.link>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Application Roles -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-medium text-gray-900">Application Roles</h3>
            <p class="mt-1 text-sm text-gray-500">
              Roles defined by individual applications during deployment
            </p>
          </div>
          
          <div class="p-6">
            <%= if Enum.any?(@all_apps, &(!Enum.empty?(&1.app_roles))) do %>
              <div class="space-y-6">
                <div :for={app <- @all_apps} :if={!Enum.empty?(app.app_roles)} class="border border-gray-200 rounded-lg p-4">
                  <h4 class="text-md font-medium text-gray-900 mb-3"><%= app.name %></h4>
                  <div class="space-y-3">
                    <div
                      :for={app_role <- app.app_roles}
                      class="flex items-center justify-between p-3 border border-gray-100 rounded-lg hover:bg-gray-50"
                    >
                      <div class="flex items-center">
                        <input
                          type="checkbox"
                          id={"app_role_#{app_role.id}"}
                          checked={app_role.id in @app_role_ids}
                          phx-click="toggle_app_role"
                          phx-value-app_role_id={app_role.id}
                          class="h-4 w-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500"
                        />
                        <div class="ml-3">
                          <label for={"app_role_#{app_role.id}"} class="text-sm font-medium text-gray-900 cursor-pointer">
                            <%= app_role.name %>
                            <span class="ml-1 inline-flex items-center px-1.5 py-0.5 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800">
                              <%= app_role.identifier %>
                            </span>
                          </label>
                          <p class="text-sm text-gray-500"><%= app_role.description %></p>
                        </div>
                      </div>
                      
                      <div class="flex items-center">
                        <%= if app_role.id in @app_role_ids do %>
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
                </div>
              </div>
            <% else %>
              <div class="text-center py-8">
                <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
                </svg>
                <h3 class="mt-2 text-sm font-medium text-gray-900">No application roles available</h3>
                <p class="mt-1 text-sm text-gray-500">Deploy applications with role definitions to see app-specific roles here.</p>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Current Assignments Summary -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-medium text-gray-900">Current Role Assignments</h3>
          </div>
          <div class="p-6">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <!-- System Roles -->
              <div>
                <h4 class="text-sm font-medium text-gray-900 mb-3">System Roles</h4>
                <%= if Enum.empty?(@system_role_ids) do %>
                  <p class="text-sm text-gray-500">No system roles assigned.</p>
                <% else %>
                  <div class="space-y-2">
                    <div
                      :for={role <- @all_roles}
                      :if={role.id in @system_role_ids}
                      class="flex items-center justify-between p-2 bg-blue-50 border border-blue-200 rounded-lg"
                    >
                      <div>
                        <p class="text-sm font-medium text-blue-900"><%= role.name %></p>
                      </div>
                      <button
                        phx-click="toggle_system_role"
                        phx-value-role_id={role.id}
                        class="text-blue-600 hover:text-blue-800 text-sm"
                      >
                        Remove
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>

              <!-- App Roles -->
              <div>
                <h4 class="text-sm font-medium text-gray-900 mb-3">Application Roles</h4>
                <%= if Enum.empty?(@app_role_ids) do %>
                  <p class="text-sm text-gray-500">No app roles assigned.</p>
                <% else %>
                  <div class="space-y-2">
                    <%= for app <- @all_apps, app_role <- app.app_roles, app_role.id in @app_role_ids do %>
                      <div class="flex items-center justify-between p-2 bg-indigo-50 border border-indigo-200 rounded-lg">
                        <div>
                          <p class="text-sm font-medium text-indigo-900"><%= app_role.name %></p>
                          <p class="text-xs text-indigo-700">from <%= app.name %></p>
                        </div>
                        <button
                          phx-click="toggle_app_role"
                          phx-value-app_role_id={app_role.id}
                          class="text-indigo-600 hover:text-indigo-800 text-sm"
                        >
                          Remove
                        </button>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end