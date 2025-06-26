defmodule ElixihubWeb.Admin.RoleLive.Index do
  use ElixihubWeb, :live_view

  alias Elixihub.Authorization
  alias Elixihub.Authorization.Role

  on_mount {ElixihubWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    
    unless Authorization.user_has_permission?(user, "admin:access") do
      {:ok, redirect(socket, to: ~p"/")}
    else
      {:ok, assign(socket, :roles, Authorization.list_roles())}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Manage Roles")
    |> assign(:role, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Role")
    |> assign(:role, %Role{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Role")
    |> assign(:role, Authorization.get_role!(id))
  end

  @impl true
  def handle_info({ElixihubWeb.Admin.RoleLive.FormComponent, {:saved, _role}}, socket) do
    {:noreply, assign(socket, :roles, Authorization.list_roles())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    role = Authorization.get_role!(id)
    
    # Prevent deletion of essential roles
    if role.name in ["admin", "user"] do
      {:noreply, put_flash(socket, :error, "Cannot delete essential system roles")}
    else
      {:ok, _} = Authorization.delete_role(role)
      {:noreply, 
       socket
       |> assign(:roles, Authorization.list_roles())
       |> put_flash(:info, "Role deleted successfully")
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
              <h1 class="text-3xl font-bold text-gray-900 mt-2">Manage Roles</h1>
              <p class="mt-1 text-sm text-gray-500">Create and configure user roles and their permissions</p>
            </div>
            <div>
              <.link
                patch={~p"/admin/roles/new"}
                class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
              >
                New Role
              </.link>
            </div>
          </div>
        </div>
      </div>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
            <h3 class="text-lg leading-6 font-medium text-gray-900">
              All Roles
            </h3>
            <p class="mt-1 max-w-2xl text-sm text-gray-500">
              Manage system roles and their permission assignments
            </p>
          </div>
          
          <ul role="list" class="divide-y divide-gray-200" id="roles">
            <li
              :for={role <- @roles}
              id={"role-#{role.id}"}
              class="px-4 py-4 hover:bg-gray-50"
            >
              <div class="flex items-center justify-between">
                <div class="flex-1">
                  <div class="flex items-center">
                    <h4 class="text-lg font-medium text-gray-900"><%= role.name %></h4>
                    <%= if role.name in ["admin", "user"] do %>
                      <span class="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                        System Role
                      </span>
                    <% end %>
                  </div>
                  <p class="text-sm text-gray-500 mt-1"><%= role.description %></p>
                  <div class="text-xs text-gray-400 mt-1">
                    Created: <%= Calendar.strftime(role.inserted_at, "%B %d, %Y at %I:%M %p") %>
                  </div>
                </div>
                
                <div class="flex items-center space-x-2">
                  <.link
                    navigate={~p"/admin/roles/#{role}/permissions"}
                    class="text-blue-600 hover:text-blue-900 text-sm font-medium"
                  >
                    Manage Permissions
                  </.link>
                  
                  <.link
                    patch={~p"/admin/roles/#{role}/edit"}
                    class="text-green-600 hover:text-green-900 text-sm font-medium"
                  >
                    Edit
                  </.link>
                  
                  <%= unless role.name in ["admin", "user"] do %>
                    <button
                      phx-click="delete"
                      phx-value-id={role.id}
                      data-confirm="Are you sure you want to delete this role? This will remove it from all users."
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
            :if={Enum.empty?(@roles)}
            class="text-center py-12"
          >
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">No roles found</h3>
            <p class="mt-1 text-sm text-gray-500">Get started by creating a new role.</p>
            <div class="mt-6">
              <.link
                patch={~p"/admin/roles/new"}
                class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
              >
                Create Role
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="role-modal"
      show
      on_cancel={JS.patch(~p"/admin/roles")}
    >
      <.live_component
        module={ElixihubWeb.Admin.RoleLive.FormComponent}
        id={@role.id || :new}
        title={@page_title}
        action={@live_action}
        role={@role}
        patch={~p"/admin/roles"}
      />
    </.modal>
    """
  end
end