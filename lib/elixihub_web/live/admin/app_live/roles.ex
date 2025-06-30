defmodule ElixihubWeb.Admin.AppLive.Roles do
  use ElixihubWeb, :live_view

  alias Elixihub.Apps
  alias Elixihub.Authorization

  on_mount {ElixihubWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(%{"id" => app_id}, _session, socket) do
    user = socket.assigns.current_user
    
    unless Authorization.user_has_permission?(user, "admin:access") do
      {:ok, redirect(socket, to: ~p"/")}
    else
      app = Apps.get_app!(app_id)
      app_roles = Apps.list_app_roles(app_id)
      
      {:ok, 
       socket
       |> assign(:app, app)
       |> assign(:app_roles, app_roles)
       |> assign(:page_title, "Manage App Roles - #{app.name}")
      }
    end
  end

  @impl true
  def handle_event("delete_role", %{"id" => role_id}, socket) do
    app_role = Apps.get_app_role!(role_id)
    {:ok, _} = Apps.delete_app_role(app_role)

    socket = 
      socket
      |> assign(:app_roles, Apps.list_app_roles(socket.assigns.app.id))
      |> put_flash(:info, "App role deleted successfully")

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
              <.link navigate={~p"/admin/apps"} class="text-blue-600 hover:text-blue-800 text-sm font-medium">
                ← Back to Applications
              </.link>
              <h1 class="text-3xl font-bold text-gray-900 mt-2">App Roles</h1>
              <p class="mt-1 text-sm text-gray-500">Manage roles for <%= @app.name %></p>
            </div>
          </div>
        </div>
      </div>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
            <h3 class="text-lg leading-6 font-medium text-gray-900">
              Application Roles
            </h3>
            <p class="mt-1 max-w-2xl text-sm text-gray-500">
              Roles defined by the application during deployment
            </p>
          </div>

          <div :if={Enum.empty?(@app_roles)} class="text-center py-12">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">No roles defined</h3>
            <p class="mt-1 text-sm text-gray-500">
              This application has not defined any roles yet. Roles are automatically detected during deployment.
            </p>
            <div class="mt-6">
              <div class="bg-blue-50 border border-blue-200 rounded-md p-4">
                <div class="flex">
                  <div class="ml-3">
                    <h3 class="text-sm font-medium text-blue-800">
                      How to Define App Roles
                    </h3>
                    <div class="mt-2 text-sm text-blue-700">
                      <p>Create a <code class="bg-blue-100 px-1 rounded">roles.json</code> file in your application root:</p>
                      <pre class="mt-2 bg-blue-100 p-2 rounded text-xs overflow-x-auto"><%= roles_example() %></pre>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <ul :if={!Enum.empty?(@app_roles)} role="list" class="divide-y divide-gray-200">
            <li :for={role <- @app_roles} class="px-4 py-4 hover:bg-gray-50">
              <div class="flex items-center justify-between">
                <div class="flex-1">
                  <div class="flex items-center">
                    <h4 class="text-lg font-medium text-gray-900"><%= role.name %></h4>
                    <span class="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                      <%= role.identifier %>
                    </span>
                  </div>
                  <p class="text-sm text-gray-500 mt-1"><%= role.description %></p>
                  
                  <div class="mt-2">
                    <h5 class="text-sm font-medium text-gray-700">Permissions:</h5>
                    <div class="mt-1 flex flex-wrap gap-1">
                      <span :for={{key, value} <- role.permissions} class={"inline-flex items-center px-2 py-1 rounded-full text-xs font-medium #{if value, do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800"}"}>
                        <%= key %>: <%= if value, do: "✓", else: "✗" %>
                      </span>
                    </div>
                  </div>

                  <div :if={role.metadata && map_size(role.metadata) > 0} class="mt-2">
                    <h5 class="text-sm font-medium text-gray-700">Metadata:</h5>
                    <div class="mt-1 flex flex-wrap gap-1">
                      <span :for={{key, value} <- role.metadata} class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                        <%= key %>: <%= value %>
                      </span>
                    </div>
                  </div>

                  <div class="text-xs text-gray-400 mt-2">
                    Created: <%= Calendar.strftime(role.inserted_at, "%B %d, %Y at %I:%M %p") %>
                  </div>
                </div>
                
                <div class="flex items-center space-x-2">
                  <.link
                    navigate={~p"/admin/users?app_role_id=#{role.id}"}
                    class="text-blue-600 hover:text-blue-900 text-sm font-medium"
                  >
                    Assign Users
                  </.link>
                  
                  <button
                    phx-click="delete_role"
                    phx-value-id={role.id}
                    data-confirm="Are you sure you want to delete this role? Users with this role will lose access."
                    class="text-red-600 hover:text-red-900 text-sm font-medium"
                  >
                    Delete
                  </button>
                </div>
              </div>
            </li>
          </ul>
        </div>

        <div class="mt-6 bg-yellow-50 border border-yellow-200 rounded-md p-4">
          <div class="flex">
            <div class="flex-shrink-0">
              <svg class="h-5 w-5 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
              </svg>
            </div>
            <div class="ml-3">
              <h3 class="text-sm font-medium text-yellow-800">
                Important Note
              </h3>
              <div class="mt-2 text-sm text-yellow-700">
                <p>App roles are automatically synced during application deployment. Manual changes to roles here may be overwritten when the application is redeployed.</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp roles_example do
    """
{
  "roles": [
    {
      "identifier": "admin",
      "name": "Administrator", 
      "description": "Full access to app",
      "permissions": {
        "read": true,
        "write": true,
        "delete": true
      }
    }
  ]
}
"""
  end
end