defmodule ElixihubWeb.AppsLive do
  use ElixihubWeb, :live_view

  alias Elixihub.Apps
  alias Elixihub.Authorization

  on_mount {ElixihubWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    
    # Check if user has permission to view apps
    unless Authorization.user_has_permission?(user, "app:read") do
      {:ok, redirect(socket, to: ~p"/")}
    else
      # Get active apps that the user can access
      active_apps = Apps.list_active_apps()
      user_permissions = Authorization.get_user_permissions(user)
      
      # Check if user is admin or has app management permissions
      can_manage_apps = Authorization.user_has_permission?(user, "admin:access") or
                       Authorization.user_has_permission?(user, "app:write")
      
      {:ok,
       socket
       |> assign(:page_title, "My Applications")
       |> assign(:active_apps, active_apps)
       |> assign(:user_permissions, user_permissions)
       |> assign(:can_manage_apps, can_manage_apps)
       |> assign(:search_query, "")
       |> assign(:filtered_apps, active_apps)
      }
    end
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    filtered_apps = filter_apps(socket.assigns.active_apps, query)
    
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:filtered_apps, filtered_apps)
    }
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:filtered_apps, socket.assigns.active_apps)
    }
  end

  defp filter_apps(apps, query) when query == "" or is_nil(query), do: apps
  
  defp filter_apps(apps, query) do
    query = String.downcase(query)
    
    Enum.filter(apps, fn app ->
      String.contains?(String.downcase(app.name), query) or
      String.contains?(String.downcase(app.description), query)
    end)
  end

  defp app_status_badge(status) do
    case status do
      "active" -> "bg-green-100 text-green-800"
      "inactive" -> "bg-red-100 text-red-800"
      "pending" -> "bg-yellow-100 text-yellow-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Header -->
      <div class="bg-white shadow">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between items-center py-6">
            <div>
              <.link navigate={~p"/"} class="text-blue-600 hover:text-blue-800 text-sm font-medium">
                ← Back to Home
              </.link>
              <h1 class="text-3xl font-bold text-gray-900 mt-2">My Applications</h1>
              <p class="mt-1 text-sm text-gray-500">Access your registered applications and services</p>
            </div>
            
            <%= if @can_manage_apps do %>
              <div>
                <.link
                  navigate={~p"/admin/apps"}
                  class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
                >
                  <svg class="mr-2 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                  </svg>
                  Manage Apps
                </.link>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <!-- Search Bar -->
        <div class="mb-8">
          <div class="max-w-md">
            <.form for={%{}} as={:search} phx-change="search" phx-submit="search" class="relative">
              <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
              </div>
              <input
                type="text"
                name="search[query]"
                value={@search_query}
                placeholder="Search applications..."
                class="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md leading-5 bg-white placeholder-gray-500 focus:outline-none focus:placeholder-gray-400 focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
              />
              <%= if @search_query != "" do %>
                <button
                  type="button"
                  phx-click="clear_search"
                  class="absolute inset-y-0 right-0 pr-3 flex items-center"
                >
                  <svg class="h-5 w-5 text-gray-400 hover:text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              <% end %>
            </.form>
          </div>
          
          <%= if @search_query != "" do %>
            <p class="mt-2 text-sm text-gray-600">
              Found <%= length(@filtered_apps) %> application(s) matching "<%= @search_query %>"
            </p>
          <% end %>
        </div>

        <!-- Apps Grid -->
        <%= if Enum.empty?(@filtered_apps) do %>
          <div class="text-center py-12">
            <%= if @search_query != "" do %>
              <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
              <h3 class="mt-2 text-sm font-medium text-gray-900">No applications found</h3>
              <p class="mt-1 text-sm text-gray-500">Try adjusting your search terms.</p>
              <div class="mt-6">
                <button
                  phx-click="clear_search"
                  class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
                >
                  Clear search
                </button>
              </div>
            <% else %>
              <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
              </svg>
              <h3 class="mt-2 text-sm font-medium text-gray-900">No applications available</h3>
              <p class="mt-1 text-sm text-gray-500">There are no active applications registered in the system yet.</p>
              <%= if @can_manage_apps do %>
                <div class="mt-6">
                  <.link
                    navigate={~p"/admin/apps"}
                    class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
                  >
                    Register Application
                  </.link>
                </div>
              <% end %>
            <% end %>
          </div>
        <% else %>
          <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
            <div
              :for={app <- @filtered_apps}
              class="group relative bg-white rounded-lg shadow-sm border border-gray-200 hover:shadow-md transition-shadow duration-200"
            >
              <div class="p-6">
                <!-- App Header -->
                <div class="flex items-center justify-between mb-4">
                  <div class="flex items-center">
                    <div class="h-10 w-10 bg-gradient-to-br from-blue-500 to-blue-600 rounded-lg flex items-center justify-center">
                      <span class="text-white font-medium text-lg">
                        <%= String.first(app.name) |> String.upcase() %>
                      </span>
                    </div>
                    <div class="ml-3">
                      <h3 class="text-lg font-medium text-gray-900 group-hover:text-blue-600">
                        <%= app.name %>
                      </h3>
                    </div>
                  </div>
                  
                  <span class={[
                    "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                    app_status_badge(app.status)
                  ]}>
                    <%= String.capitalize(app.status) %>
                  </span>
                </div>

                <!-- App Description -->
                <p class="text-sm text-gray-600 mb-4 line-clamp-2">
                  <%= app.description %>
                </p>

                <!-- App URL -->
                <div class="mb-4">
                  <p class="text-xs text-gray-500 mb-1">Application URL</p>
                  <a
                    href={app.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="text-sm text-blue-600 hover:text-blue-800 break-all"
                  >
                    <%= app.url %>
                    <svg class="inline h-3 w-3 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                    </svg>
                  </a>
                </div>

                <!-- Action Button -->
                <div class="pt-4 border-t border-gray-200">
                  <a
                    href={app.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="w-full inline-flex justify-center items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 transition-colors"
                  >
                    Launch Application
                    <svg class="ml-2 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                    </svg>
                  </a>
                </div>

                <!-- Registration Date -->
                <div class="mt-4 text-xs text-gray-400">
                  Registered <%= Calendar.strftime(app.inserted_at, "%B %d, %Y") %>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <!-- User Info Panel -->
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-8">
        <div class="bg-blue-50 rounded-lg p-6">
          <h3 class="text-lg font-medium text-blue-900 mb-4">Your Access Level</h3>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <h4 class="text-sm font-medium text-blue-800 mb-2">Your Permissions</h4>
              <div class="space-y-1">
                <%= for permission <- @user_permissions do %>
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800 mr-2 mb-1">
                    <%= permission.name %>
                  </span>
                <% end %>
              </div>
            </div>
            
            <div>
              <h4 class="text-sm font-medium text-blue-800 mb-2">Quick Actions</h4>
              <div class="space-y-2">
                <.link
                  navigate={~p"/users/settings"}
                  class="block text-sm text-blue-700 hover:text-blue-900"
                >
                  → Account Settings
                </.link>
                <%= if @can_manage_apps do %>
                  <.link
                    navigate={~p"/admin/apps"}
                    class="block text-sm text-blue-700 hover:text-blue-900"
                  >
                    → Manage Applications
                  </.link>
                <% end %>
                <%= if Authorization.user_has_permission?(@current_user, "admin:access") do %>
                  <.link
                    navigate={~p"/admin"}
                    class="block text-sm text-blue-700 hover:text-blue-900"
                  >
                    → Admin Dashboard
                  </.link>
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