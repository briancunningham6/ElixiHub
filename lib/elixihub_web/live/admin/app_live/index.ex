defmodule ElixihubWeb.Admin.AppLive.Index do
  use ElixihubWeb, :live_view

  alias Elixihub.Apps
  alias Elixihub.Apps.App
  alias Elixihub.Authorization

  on_mount {ElixihubWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    
    unless Authorization.user_has_permission?(user, "admin:access") do
      {:ok, redirect(socket, to: ~p"/")}
    else
      {:ok, assign(socket, :apps, Apps.list_apps())}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Manage Applications")
    |> assign(:app, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Application")
    |> assign(:app, %App{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Application")
    |> assign(:app, Apps.get_app!(id))
  end

  @impl true
  def handle_info({ElixihubWeb.Admin.AppLive.FormComponent, {:saved, _app}}, socket) do
    {:noreply, assign(socket, :apps, Apps.list_apps())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    app = Apps.get_app!(id)
    {:ok, _} = Apps.delete_app(app)

    {:noreply, 
     socket
     |> assign(:apps, Apps.list_apps())
     |> put_flash(:info, "Application deleted successfully")
    }
  end

  @impl true
  def handle_event("toggle_status", %{"id" => id}, socket) do
    app = Apps.get_app!(id)
    
    {_updated_app, message} = case app.status do
      "active" -> 
        {:ok, updated} = Apps.update_app(app, %{status: "inactive"})
        {updated, "Application deactivated"}
      _ -> 
        {:ok, updated} = Apps.update_app(app, %{status: "active"})
        {updated, "Application activated"}
    end

    {:noreply,
     socket
     |> assign(:apps, Apps.list_apps())
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
              <.link navigate={~p"/admin"} class="text-blue-600 hover:text-blue-800 text-sm font-medium">
                ← Back to Dashboard
              </.link>
              <h1 class="text-3xl font-bold text-gray-900 mt-2">Manage Applications</h1>
              <p class="mt-1 text-sm text-gray-500">Register and configure external applications</p>
            </div>
            <div>
              <.link
                patch={~p"/admin/apps/new"}
                class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
              >
                Register New App
              </.link>
            </div>
          </div>
        </div>
      </div>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
            <h3 class="text-lg leading-6 font-medium text-gray-900">
              Registered Applications
            </h3>
            <p class="mt-1 max-w-2xl text-sm text-gray-500">
              Manage external applications that integrate with ElixiHub
            </p>
          </div>
          
          <ul role="list" class="divide-y divide-gray-200" id="apps">
            <li
              :for={app <- @apps}
              id={"app-#{app.id}"}
              class="px-4 py-4 hover:bg-gray-50"
            >
              <div class="flex items-center justify-between">
                <div class="flex-1">
                  <div class="flex items-center">
                    <h4 class="text-lg font-medium text-gray-900"><%= app.name %></h4>
                    <span class={[
                      "ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                      if app.status == "active" do
                        "bg-green-100 text-green-800"
                      else
                        "bg-red-100 text-red-800"
                      end
                    ]}>
                      <%= String.capitalize(app.status) %>
                    </span>
                  </div>
                  <p class="text-sm text-gray-500 mt-1"><%= app.description %></p>
                  <div class="text-sm text-gray-600 mt-1">
                    URL: <a href={app.url} target="_blank" class="text-blue-600 hover:text-blue-800"><%= app.url %></a>
                  </div>
                  <div class="text-xs text-gray-400 mt-1">
                    API Key: <code class="bg-gray-100 px-2 py-1 rounded text-xs"><%= app.api_key %></code>
                  </div>
                  <div class="text-xs text-gray-400 mt-1">
                    Node: <%= if app.node do %>
                      <span class="text-gray-600"><%= app.node.name %>@<%= app.node.host %></span>
                      <%= if app.node.is_current do %>
                        <span class="text-blue-600">(Current)</span>
                      <% end %>
                    <% else %>
                      <span class="text-gray-500">Not assigned</span>
                    <% end %>
                  </div>
                  <div class="text-xs text-gray-400 mt-1">
                    Registered: <%= Calendar.strftime(app.inserted_at, "%B %d, %Y at %I:%M %p") %>
                  </div>
                </div>
                
                <div class="flex items-center space-x-2">
                  <button
                    phx-click="toggle_status"
                    phx-value-id={app.id}
                    class={[
                      "text-sm font-medium",
                      if app.status == "active" do
                        "text-red-600 hover:text-red-900"
                      else
                        "text-green-600 hover:text-green-900"
                      end
                    ]}
                  >
                    <%= if app.status == "active", do: "Deactivate", else: "Activate" %>
                  </button>
                  
                  <.link
                    patch={~p"/admin/apps/#{app}/edit"}
                    class="text-blue-600 hover:text-blue-900 text-sm font-medium"
                  >
                    Edit
                  </.link>
                  
                  <button
                    phx-click="delete"
                    phx-value-id={app.id}
                    data-confirm="Are you sure you want to delete this application? This action cannot be undone."
                    class="text-red-600 hover:text-red-900 text-sm font-medium"
                  >
                    Delete
                  </button>
                </div>
              </div>
            </li>
          </ul>
          
          <div
            :if={Enum.empty?(@apps)}
            class="text-center py-12"
          >
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">No applications registered</h3>
            <p class="mt-1 text-sm text-gray-500">Get started by registering your first application.</p>
            <div class="mt-6">
              <.link
                patch={~p"/admin/apps/new"}
                class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
              >
                Register Application
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="app-modal"
      show
      on_cancel={JS.patch(~p"/admin/apps")}
    >
      <.live_component
        module={ElixihubWeb.Admin.AppLive.FormComponent}
        id={@app.id || :new}
        title={@page_title}
        action={@live_action}
        app={@app}
        patch={~p"/admin/apps"}
      />
    </.modal>
    """
  end
end