defmodule ElixihubWeb.Admin.UserLive.Index do
  use ElixihubWeb, :live_view

  alias Elixihub.Accounts
  alias Elixihub.Authorization

  on_mount {ElixihubWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    
    unless Authorization.user_has_permission?(user, "admin:access") do
      {:ok, redirect(socket, to: ~p"/")}
    else
      {:ok, assign(socket, :users, list_users_with_roles())}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Manage Users")
    |> assign(:user, nil)
  end

  @impl true
  def handle_info({ElixihubWeb.Admin.UserLive.FormComponent, {:saved, _user}}, socket) do
    {:noreply, assign(socket, :users, list_users_with_roles())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    current_user = socket.assigns.current_user
    
    # Prevent users from deleting themselves
    if user.id == current_user.id do
      {:noreply, put_flash(socket, :error, "You cannot delete your own account")}
    else
      {:ok, _} = Accounts.delete_user(user)
      {:noreply, 
       socket
       |> assign(:users, list_users_with_roles())
       |> put_flash(:info, "User deleted successfully")
      }
    end
  end

  defp list_users_with_roles do
    Accounts.list_users()
    |> Enum.map(fn user ->
      user = Elixihub.Repo.preload(user, :roles)
      %{user | roles: user.roles}
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
              <.link navigate={~p"/admin"} class="text-blue-600 hover:text-blue-800 text-sm font-medium">
                ← Back to Dashboard
              </.link>
              <h1 class="text-3xl font-bold text-gray-900 mt-2">Manage Users</h1>
              <p class="mt-1 text-sm text-gray-500">View and manage user accounts and their roles</p>
            </div>
          </div>
        </div>
      </div>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="bg-white shadow overflow-hidden sm:rounded-md">
          <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
            <h3 class="text-lg leading-6 font-medium text-gray-900">
              All Users
            </h3>
            <p class="mt-1 max-w-2xl text-sm text-gray-500">
              Manage user accounts and their role assignments
            </p>
          </div>
          
          <ul role="list" class="divide-y divide-gray-200" id="users">
            <li
              :for={user <- @users}
              id={"user-#{user.id}"}
              class="px-4 py-4 flex items-center justify-between hover:bg-gray-50"
            >
              <div class="flex items-center">
                <div class="flex-shrink-0 h-10 w-10">
                  <div class="h-10 w-10 rounded-full bg-gray-300 flex items-center justify-center">
                    <span class="text-sm font-medium text-gray-700">
                      <%= String.first(user.email) |> String.upcase() %>
                    </span>
                  </div>
                </div>
                <div class="ml-4">
                  <div class="text-sm font-medium text-gray-900"><%= user.email %></div>
                  <div class="text-sm text-gray-500">
                    Roles: 
                    <%= if Enum.empty?(user.roles) do %>
                      <span class="text-gray-400">No roles assigned</span>
                    <% else %>
                      <%= Enum.map_join(user.roles, ", ", & &1.name) %>
                    <% end %>
                  </div>
                  <div class="text-xs text-gray-400">
                    Joined: <%= Calendar.strftime(user.inserted_at, "%B %d, %Y") %>
                    <%= if user.confirmed_at do %>
                      • <span class="text-green-600">Confirmed</span>
                    <% else %>
                      • <span class="text-yellow-600">Unconfirmed</span>
                    <% end %>
                  </div>
                </div>
              </div>
              
              <div class="flex items-center space-x-2">
                <.link
                  navigate={~p"/admin/users/#{user}/roles"}
                  class="text-blue-600 hover:text-blue-900 text-sm font-medium"
                >
                  Manage Roles
                </.link>
                
                <%= if user.id != @current_user.id do %>
                  <button
                    phx-click="delete"
                    phx-value-id={user.id}
                    data-confirm="Are you sure you want to delete this user? This action cannot be undone."
                    class="text-red-600 hover:text-red-900 text-sm font-medium"
                  >
                    Delete
                  </button>
                <% else %>
                  <span class="text-gray-400 text-sm">Current User</span>
                <% end %>
              </div>
            </li>
          </ul>
          
          <div
            :if={Enum.empty?(@users)}
            class="text-center py-12"
          >
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">No users found</h3>
            <p class="mt-1 text-sm text-gray-500">Get started by registering your first user.</p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end