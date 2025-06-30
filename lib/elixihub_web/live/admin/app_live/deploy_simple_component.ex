defmodule ElixihubWeb.Admin.AppLive.DeploySimpleComponent do
  use ElixihubWeb, :live_component

  alias Elixihub.Apps
  alias Elixihub.Hosts

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Deploy <%= @app.name %>
        <:subtitle>Configure SSH settings for deployment</:subtitle>
      </.header>

      <.simple_form for={@form} id="deploy-form" phx-target={@myself} phx-submit="deploy" phx-change="validate">
        <.input 
          field={@form[:host_id]} 
          type="select" 
          label="Deployment Host" 
          options={@host_options}
          prompt="Select a host..."
          required 
        />
        <.input field={@form[:ssh_username]} type="text" label="SSH Username" placeholder="ubuntu" required />
        <.input field={@form[:deploy_path]} type="text" label="Deploy Path" placeholder="/opt/apps/myapp" required />
        
        <div class="bg-blue-50 border border-blue-200 rounded-md p-4">
          <div class="flex">
            <div class="ml-3">
              <h3 class="text-sm font-medium text-blue-800">
                Host-based Deployment
              </h3>
              <div class="mt-2 text-sm text-blue-700">
                <p>Select a configured host from the dropdown. The host's SSH settings will be used for deployment.</p>
                <p class="mt-1">Need to add a new host? <a href="/admin/hosts" class="underline">Manage Hosts</a></p>
              </div>
            </div>
          </div>
        </div>
        
        <:actions>
          <.button phx-disable-with="Saving...">
            Save Deployment Configuration
          </.button>
          <.button type="button" phx-click="cancel" phx-target={@myself} class="bg-gray-500 hover:bg-gray-600">
            Cancel
          </.button>
        </:actions>
      </.simple_form>

      <div :if={@app.deployment_status != "pending"} class="mt-6">
        <h3 class="text-lg font-medium text-gray-900 mb-3">Deployment Status</h3>
        <div class="flex items-center space-x-3">
          <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{status_color(@app.deployment_status)}"}>
            <%= String.capitalize(@app.deployment_status) %>
          </span>
          <span :if={@app.deployed_at} class="text-sm text-gray-500">
            Deployed: <%= format_datetime(@app.deployed_at) %>
          </span>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def update(%{app: app} = assigns, socket) do
    changeset = Apps.change_app(app)
    host_options = Hosts.get_host_options()

    socket =
      socket
      |> assign(assigns)
      |> assign(:form, to_form(changeset))
      |> assign(:host_options, host_options)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"app" => app_params}, socket) do
    changeset =
      socket.assigns.app
      |> Apps.change_app(app_params)
      |> Map.put(:action, :validate)

    socket = assign(socket, form: to_form(changeset))
    {:noreply, socket}
  end

  @impl true
  def handle_event("deploy", %{"app" => app_params}, socket) do
    app = socket.assigns.app

    # Update app with deployment config
    update_params = %{
      host_id: app_params["host_id"],
      ssh_username: app_params["ssh_username"],
      deploy_path: app_params["deploy_path"]
    }

    case Apps.update_app(app, update_params) do
      {:ok, _updated_app} ->
        socket =
          socket
          |> put_flash(:info, "Deployment configuration saved successfully!")
          |> push_patch(to: ~p"/admin/apps")

        {:noreply, socket}

      {:error, changeset} ->
        socket = assign(socket, form: to_form(changeset))
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/apps")}
  end

  defp status_color("pending"), do: "bg-yellow-100 text-yellow-800"
  defp status_color("deploying"), do: "bg-blue-100 text-blue-800"
  defp status_color("deployed"), do: "bg-green-100 text-green-800"
  defp status_color("failed"), do: "bg-red-100 text-red-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end
end