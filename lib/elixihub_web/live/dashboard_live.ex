defmodule ElixihubWeb.DashboardLive do
  use ElixihubWeb, :live_view

  alias Elixihub.Accounts
  alias Elixihub.Authorization
  alias Elixihub.Apps

  on_mount {ElixihubWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    # Check if user has admin access
    unless Authorization.user_has_permission?(user, "admin:access") do
      {:ok, redirect(socket, to: ~p"/")}
    else
      {:ok,
       socket
       |> assign(:page_title, "Admin Dashboard")
       |> assign(:users_count, Accounts.list_users() |> length())
       |> assign(:roles_count, Authorization.list_roles() |> length())
       |> assign(:permissions_count, Authorization.list_permissions() |> length())
       |> assign(:apps_count, Apps.list_apps() |> length())
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
              <h1 class="text-3xl font-bold text-gray-900">Admin Dashboard</h1>
              <p class="mt-1 text-sm text-gray-500">Manage users, roles, permissions, and applications</p>
            </div>
            <div class="flex space-x-4">
            </div>
          </div>
        </div>
      </div>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <!-- Statistics Cards -->
        <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4 mb-8">
          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z" />
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Total Users</dt>
                    <dd class="text-lg font-medium text-gray-900"><%= @users_count %></dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Roles</dt>
                    <dd class="text-lg font-medium text-gray-900"><%= @roles_count %></dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Permissions</dt>
                    <dd class="text-lg font-medium text-gray-900"><%= @permissions_count %></dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Applications</dt>
                    <dd class="text-lg font-medium text-gray-900"><%= @apps_count %></dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Quick Actions -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Quick Actions</h3>
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
              <.link
                navigate={~p"/admin/users"}
                class="relative group bg-white p-6 focus-within:ring-2 focus-within:ring-inset focus-within:ring-blue-500 rounded-lg border border-gray-300 hover:border-gray-400"
              >
                <div>
                  <span class="rounded-lg inline-flex p-3 bg-blue-50 text-blue-700 ring-4 ring-white">
                    <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z" />
                    </svg>
                  </span>
                </div>
                <div class="mt-8">
                  <h3 class="text-lg font-medium">
                    <span class="absolute inset-0" aria-hidden="true"></span>
                    Manage Users
                  </h3>
                  <p class="mt-2 text-sm text-gray-500">
                    View, edit, and manage user accounts and their roles.
                  </p>
                </div>
              </.link>

              <.link
                navigate={~p"/admin/roles"}
                class="relative group bg-white p-6 focus-within:ring-2 focus-within:ring-inset focus-within:ring-blue-500 rounded-lg border border-gray-300 hover:border-gray-400"
              >
                <div>
                  <span class="rounded-lg inline-flex p-3 bg-green-50 text-green-700 ring-4 ring-white">
                    <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                  </span>
                </div>
                <div class="mt-8">
                  <h3 class="text-lg font-medium">
                    <span class="absolute inset-0" aria-hidden="true"></span>
                    Manage Roles
                  </h3>
                  <p class="mt-2 text-sm text-gray-500">
                    Create and configure user roles and their permissions.
                  </p>
                </div>
              </.link>

              <.link
                navigate={~p"/admin/permissions"}
                class="relative group bg-white p-6 focus-within:ring-2 focus-within:ring-inset focus-within:ring-blue-500 rounded-lg border border-gray-300 hover:border-gray-400"
              >
                <div>
                  <span class="rounded-lg inline-flex p-3 bg-yellow-50 text-yellow-700 ring-4 ring-white">
                    <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                    </svg>
                  </span>
                </div>
                <div class="mt-8">
                  <h3 class="text-lg font-medium">
                    <span class="absolute inset-0" aria-hidden="true"></span>
                    Manage Permissions
                  </h3>
                  <p class="mt-2 text-sm text-gray-500">
                    Define and organize system permissions.
                  </p>
                </div>
              </.link>

              <.link
                navigate={~p"/admin/apps"}
                class="relative group bg-white p-6 focus-within:ring-2 focus-within:ring-inset focus-within:ring-blue-500 rounded-lg border border-gray-300 hover:border-gray-400"
              >
                <div>
                  <span class="rounded-lg inline-flex p-3 bg-purple-50 text-purple-700 ring-4 ring-white">
                    <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
                    </svg>
                  </span>
                </div>
                <div class="mt-8">
                  <h3 class="text-lg font-medium">
                    <span class="absolute inset-0" aria-hidden="true"></span>
                    Manage Applications
                  </h3>
                  <p class="mt-2 text-sm text-gray-500">
                    Register and configure external applications.
                  </p>
                </div>
              </.link>

              <.link
                navigate={~p"/admin/nodes"}
                class="relative group bg-white p-6 focus-within:ring-2 focus-within:ring-inset focus-within:ring-blue-500 rounded-lg border border-gray-300 hover:border-gray-400"
              >
                <div>
                  <span class="rounded-lg inline-flex p-3 bg-indigo-50 text-indigo-700 ring-4 ring-white">
                    <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h6a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h6a2 2 0 002-2v-4a2 2 0 00-2-2m8-12V4a2 2 0 012-2h4a2 2 0 012 2v4a2 2 0 01-2 2h-4a2 2 0 01-2-2V4z" />
                    </svg>
                  </span>
                </div>
                <div class="mt-8">
                  <h3 class="text-lg font-medium">
                    <span class="absolute inset-0" aria-hidden="true"></span>
                    Manage Nodes
                  </h3>
                  <p class="mt-2 text-sm text-gray-500">
                    Connect to and manage remote Elixir nodes.
                  </p>
                </div>
              </.link>

              <.link
                navigate={~p"/admin/hosts"}
                class="relative group bg-white p-6 focus-within:ring-2 focus-within:ring-inset focus-within:ring-blue-500 rounded-lg border border-gray-300 hover:border-gray-400"
              >
                <div>
                  <span class="rounded-lg inline-flex p-3 bg-red-50 text-red-700 ring-4 ring-white">
                    <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h6a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h6a2 2 0 002-2v-4a2 2 0 00-2-2m8-8v8m0-8a2 2 0 012-2h2a2 2 0 012 2v8a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                    </svg>
                  </span>
                </div>
                <div class="mt-8">
                  <h3 class="text-lg font-medium">
                    <span class="absolute inset-0" aria-hidden="true"></span>
                    Manage Hosts
                  </h3>
                  <p class="mt-2 text-sm text-gray-500">
                    Configure deployment hosts for applications.
                  </p>
                </div>
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
