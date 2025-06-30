defmodule ElixihubWeb.Admin.AppLive.DeploySelectComponent do
  use ElixihubWeb, :live_component

  alias Elixihub.Apps

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Select Application to Deploy
        <:subtitle>Choose an application to deploy to a remote server</:subtitle>
      </.header>

      <div class="mt-6">
        <div :if={Enum.empty?(@apps)} class="text-center py-8">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012 2v2M7 7h10" />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">No applications available</h3>
          <p class="mt-1 text-sm text-gray-500">You need to register an application before you can deploy it.</p>
          <div class="mt-6">
            <.link
              patch={~p"/admin/apps/new"}
              class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
            >
              Register Application
            </.link>
          </div>
        </div>

        <div :if={!Enum.empty?(@apps)} class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <div
            :for={app <- @apps}
            class="relative group bg-white p-6 focus-within:ring-2 focus-within:ring-inset focus-within:ring-blue-500 rounded-lg border border-gray-200 hover:border-blue-300 hover:shadow-md cursor-pointer transition-all duration-200"
            phx-click="select_app"
            phx-value-id={app.id}
            phx-target={@myself}
          >
            <div class="flex items-center justify-between">
              <div class="flex-1">
                <h3 class="text-lg font-medium text-gray-900 group-hover:text-blue-600">
                  <%= app.name %>
                </h3>
                <p class="text-sm text-gray-500 mt-1 line-clamp-2">
                  <%= app.description %>
                </p>
                <div class="mt-3 flex items-center space-x-3">
                  <span class={[
                    "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                    if app.status == "active" do
                      "bg-green-100 text-green-800"
                    else
                      "bg-red-100 text-red-800"
                    end
                  ]}>
                    <%= String.capitalize(app.status) %>
                  </span>
                  <span :if={app.deployment_status != "pending"} class={[
                    "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                    case app.deployment_status do
                      "deployed" -> "bg-green-100 text-green-800"
                      "deploying" -> "bg-blue-100 text-blue-800"
                      "failed" -> "bg-red-100 text-red-800"
                      _ -> "bg-gray-100 text-gray-800"
                    end
                  ]}>
                    <%= String.capitalize(app.deployment_status || "pending") %>
                  </span>
                </div>
                <div class="mt-2 text-xs text-gray-400">
                  <div>URL: <%= app.url %></div>
                  <div :if={app.node}>
                    Node: <%= app.node.name %>@<%= app.node.host %>
                    <%= if app.node.is_current do %>
                      <span class="text-blue-600">(Current)</span>
                    <% end %>
                  </div>
                  <div :if={app.deployed_at}>
                    Last deployed: <%= Calendar.strftime(app.deployed_at, "%m/%d/%y %I:%M %p") %>
                  </div>
                </div>
              </div>
              <div class="ml-4">
                <svg class="h-5 w-5 text-gray-400 group-hover:text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                </svg>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="mt-6 flex justify-end">
        <.button type="button" phx-click="cancel" phx-target={@myself} class="bg-gray-500 hover:bg-gray-600">
          Cancel
        </.button>
      </div>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    apps = Apps.list_apps()

    socket =
      socket
      |> assign(assigns)
      |> assign(:apps, apps)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_app", %{"id" => id}, socket) do
    send(self(), {:select_app_for_deploy, id})
    {:noreply, put_flash(socket, :info, "Selecting app for deployment...")}
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/apps")}
  end
end