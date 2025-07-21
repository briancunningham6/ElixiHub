defmodule ElixihubWeb.Admin.AppLive.DeployComponent do
  use ElixihubWeb, :live_component

  alias Elixihub.Deployment
  alias Elixihub.Apps

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Deploy <%= @app.name %>
        <:subtitle>Upload a tar file and deploy to remote server</:subtitle>
      </.header>

      <.simple_form for={@form} id="deploy-form" phx-target={@myself} phx-submit="deploy" phx-change="validate">
        <.input field={@form[:ssh_host]} type="text" label="SSH Host" placeholder="192.168.1.100" required />
        <.input field={@form[:ssh_port]} type="number" label="SSH Port" value="22" />
        <.input field={@form[:ssh_username]} type="text" label="SSH Username" placeholder="ubuntu" required />
        <.input field={@form[:ssh_password]} type="password" label="SSH Password" />
        <.input field={@form[:deploy_path]} type="text" label="Deploy Path" placeholder="/opt/apps/myapp" required />
        <.input field={@form[:deploy_as_service]} type="checkbox" label="Deploy as System Service" />
        
        <div class="space-y-2">
          <label class="block text-sm font-medium text-gray-700">Tar File</label>
          <live_file_input upload={@uploads.tar_file} class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-violet-50 file:text-violet-700 hover:file:bg-violet-100" />
          
          <%= for entry <- get_upload_entries(@uploads) do %>
            <div class="mt-2">
              <div class="flex items-center justify-between p-2 bg-gray-50 rounded">
                <span class="text-sm text-gray-600"><%= entry.client_name %></span>
                <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} phx-target={@myself} class="text-red-600 hover:text-red-800">
                  ✕
                </button>
              </div>
              
              <div class="w-full bg-gray-200 rounded-full h-2 mt-1">
                <div class="bg-blue-600 h-2 rounded-full transition-all duration-300" style={"width: #{entry.progress}%"}></div>
              </div>
              
              <!-- Upload errors will be shown here if needed -->
            </div>
          <% end %>
        </div>

        <:actions>
          <.button phx-disable-with="Deploying...">
            Deploy Application
          </.button>
          <.button type="button" phx-click="cancel" phx-target={@myself} class="bg-gray-500 hover:bg-gray-600">
            Cancel
          </.button>
        </:actions>
      </.simple_form>

      <div :if={@deployment_log != []} class="mt-6">
        <h3 class="text-lg font-medium text-gray-900 mb-3">Deployment Log</h3>
        <div class="bg-gray-900 text-green-400 p-4 rounded-lg font-mono text-sm max-h-64 overflow-y-auto">
          <div :for={entry <- @deployment_log} class="mb-1">
            <span class="text-gray-500"><%= format_timestamp(entry.timestamp) %></span>
            <span class="ml-2"><%= entry.message %></span>
          </div>
        </div>
      </div>

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
  def mount(socket) do
    socket =
      socket
      |> assign(:deployment_log, [])
      |> allow_upload(:tar_file,
        accept: ~w(.tar .tgz .gz),
        max_entries: 1,
        max_file_size: 100_000_000  # 100MB
      )

    {:ok, socket}
  end

  @impl true
  def update(%{app: app} = assigns, socket) do
    changeset = Apps.change_app(app)

    socket =
      socket
      |> assign(assigns)
      |> assign(:form, to_form(changeset))
      |> assign(:deployment_log, get_deployment_log(app))

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

    uploaded_files = consume_uploaded_entries(socket, :tar_file, fn %{path: path}, _entry ->
      dest = Path.join(System.tmp_dir(), "deployment_#{app.id}_#{System.system_time()}.tar")
      File.cp!(path, dest)
      {:ok, dest}
    end)

    case uploaded_files do
      [tar_path] ->
        deploy_as_service = app_params["deploy_as_service"] == "true"
        
        ssh_config = %{
          host: app_params["ssh_host"],
          port: String.to_integer(app_params["ssh_port"] || "22"),
          username: app_params["ssh_username"],
          password: app_params["ssh_password"],
          deploy_path: app_params["deploy_path"],
          deploy_as_service: deploy_as_service
        }

        # Update app with SSH config
        {:ok, updated_app} = Apps.update_app(app, %{
          ssh_host: ssh_config.host,
          ssh_port: ssh_config.port,
          ssh_username: ssh_config.username,
          deploy_path: ssh_config.deploy_path,
          deploy_as_service: deploy_as_service
        })

        # Start deployment in background
        pid = self()
        app_id = updated_app.id

        Task.start(fn ->
          case Deployment.deploy_app(updated_app, tar_path, ssh_config) do
            {:ok, result} ->
              send(pid, {:deployment_complete, app_id, :success, result})
            
            {:error, reason} ->
              send(pid, {:deployment_complete, app_id, :error, reason})
          end

          # Cleanup temp file
          File.rm(tar_path)
        end)

        socket =
          socket
          |> put_flash(:info, "Deployment started. This may take several minutes...")
          |> push_patch(to: ~p"/admin/apps")

        {:noreply, socket}

      [] ->
        socket = put_flash(socket, :error, "Please select a tar file to deploy")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :tar_file, ref)}
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/apps")}
  end

  defp get_deployment_log(app) do
    case app.deployment_log do
      logs when is_list(logs) -> logs
      logs when is_map(logs) -> Map.get(logs, "entries", [])
      _ -> []
    end
  end

  defp status_color("pending"), do: "bg-yellow-100 text-yellow-800"
  defp status_color("deploying"), do: "bg-blue-100 text-blue-800"
  defp status_color("deployed"), do: "bg-green-100 text-green-800"
  defp status_color("failed"), do: "bg-red-100 text-red-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"

  defp format_timestamp(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%H:%M:%S")
      _ -> "00:00:00"
    end
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end

  defp get_upload_entries(uploads) do
    case uploads[:tar_file] do
      %{entries: entries} -> entries
      _ -> []
    end
  end

  defp error_to_string(:too_large), do: "File too large (max 100MB)"
  defp error_to_string(:not_accepted), do: "Invalid file type (only .tar, .tgz, .gz allowed)"
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"
end