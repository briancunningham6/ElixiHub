defmodule ElixihubWeb.Admin.AppLive.DeploySimpleComponent do
  use ElixihubWeb, :live_component

  alias Elixihub.Apps
  alias Elixihub.Hosts
  alias Elixihub.Deployment

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Deploy <%= @app.name %>
        <:subtitle>Select host, deployment path, and upload application tar file</:subtitle>
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
        <.input field={@form[:deploy_path]} type="text" label="Deploy Path" placeholder="/home/{username}/dev/{app_name}" required />
        
        <!-- File Upload Section -->
        <div class="space-y-4">
          <label class="block text-sm font-medium text-gray-700">Application Archive (.tar)</label>
          <div 
            class="mt-1 flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-md"
            phx-drop-target={@uploads.tar_file.ref}
          >
            <div class="space-y-1 text-center">
              <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
                <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
              </svg>
              <div class="flex text-sm text-gray-600">
                <label class="relative cursor-pointer bg-white rounded-md font-medium text-blue-600 hover:text-blue-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-blue-500">
                  <span>Upload a file</span>
                  <.live_file_input upload={@uploads.tar_file} class="sr-only" />
                </label>
                <p class="pl-1">or drag and drop</p>
              </div>
              <p class="text-xs text-gray-500">TAR, TGZ, TAR.GZ up to 100MB</p>
            </div>
          </div>

          <!-- Upload Progress and Preview -->
          <div :for={entry <- @uploads.tar_file.entries} class="mt-4">
            <div class="flex items-center justify-between">
              <div class="flex items-center">
                <svg class="h-5 w-5 text-gray-400 mr-2" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M3 17a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm3.293-7.707a1 1 0 011.414 0L9 10.586V3a1 1 0 112 0v7.586l1.293-1.293a1 1 0 111.414 1.414l-3 3a1 1 0 01-1.414 0l-3-3a1 1 0 010-1.414z" clip-rule="evenodd" />
                </svg>
                <span class="text-sm text-gray-900"><%= entry.client_name %></span>
                <span class="text-xs text-gray-500 ml-2">(<%= format_bytes(entry.client_size) %>)</span>
              </div>
              <button type="button" phx-click="cancel-upload" phx-target={@myself} phx-value-ref={entry.ref} class="text-red-600 hover:text-red-800">
                <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                </svg>
              </button>
            </div>
            
            <!-- Progress Bar -->
            <div class="mt-2">
              <div class="bg-gray-200 rounded-full h-2">
                <div class="bg-blue-600 h-2 rounded-full transition-all duration-300" style={"width: #{entry.progress}%"}></div>
              </div>
              <p class="text-xs text-gray-500 mt-1"><%= entry.progress %>% uploaded</p>
            </div>
            
            <!-- Upload Errors -->
            <div :for={error <- upload_errors(@uploads.tar_file, entry)} class="mt-2 text-sm text-red-600">
              <%= error_to_string(error) %>
            </div>
          </div>

          <!-- General Upload Errors -->
          <div :for={error <- upload_errors(@uploads.tar_file)} class="mt-2 text-sm text-red-600">
            <%= error_to_string(error) %>
          </div>
        </div>
        
        <div class="bg-blue-50 border border-blue-200 rounded-md p-4">
          <div class="flex">
            <div class="ml-3">
              <h3 class="text-sm font-medium text-blue-800">
                Deployment Process
              </h3>
              <div class="mt-2 text-sm text-blue-700">
                <p>1. Select a configured host (includes SSH credentials)</p>
                <p>2. Upload your application tar file (.tar, .tgz, .tar.gz)</p>
                <p>3. Specify the deployment path on the target server</p>
                <p>4. Click Deploy to start the deployment process</p>
                <p class="mt-1">Need to add a new host? <a href="/admin/hosts" class="underline">Manage Hosts</a></p>
              </div>
            </div>
          </div>
        </div>
        
        <:actions>
          <.button phx-disable-with="Deploying..." disabled={length(@uploads.tar_file.entries) == 0}>
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
            </svg>
            Deploy Application
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
        
        <!-- Deployment Log -->
        <div :if={@app.deployment_log && map_size(@app.deployment_log) > 0} class="mt-4">
          <h4 class="text-sm font-medium text-gray-900 mb-2">Deployment Log</h4>
          <div class="bg-gray-900 text-green-400 p-4 rounded-lg text-sm font-mono max-h-64 overflow-y-auto">
            <div :for={{step, result} <- @app.deployment_log}>
              <span class="text-gray-400">[<%= step %>]</span> <%= result %>
            </div>
          </div>
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
      |> allow_upload(:tar_file, 
          accept: ~w(.tar .tgz .tar.gz),
          max_entries: 1,
          max_file_size: 100 * 1024 * 1024 # 100MB
        )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"app" => app_params}, socket) do
    # Generate default deploy path if host is selected and deploy_path is empty
    updated_params = maybe_set_default_deploy_path(app_params, socket.assigns.app)
    
    changeset =
      socket.assigns.app
      |> Apps.change_app(updated_params)
      |> Map.put(:action, :validate)

    socket = assign(socket, form: to_form(changeset))
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    socket = cancel_upload(socket, :tar_file, ref)
    {:noreply, socket}
  end

  @impl true
  def handle_event("deploy", %{"app" => app_params}, socket) do
    app = socket.assigns.app
    
    # Validate required fields
    with {:ok, host_id} <- validate_required_field(app_params["host_id"], "Host"),
         {:ok, deploy_path} <- validate_required_field(app_params["deploy_path"], "Deploy Path"),
         {:ok, uploaded_files} <- validate_uploaded_files(socket) do
      
      # Update app status to deploying
      {:ok, updated_app} = Apps.update_app(app, %{
        host_id: host_id,
        deploy_path: deploy_path,
        deployment_status: "deploying",
        deployment_log: %{"start" => "Deployment started at #{DateTime.utc_now()}"}
      })

      # Start deployment process asynchronously
      Task.start(fn ->
        deploy_application(updated_app, uploaded_files, socket.assigns.current_user)
      end)

      socket =
        socket
        |> put_flash(:info, "Deployment started! You can monitor progress below.")
        |> push_patch(to: ~p"/admin/apps")

      {:noreply, socket}
    else
      {:error, message} ->
        socket = put_flash(socket, :error, message)
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/apps")}
  end

  # Private functions

  defp validate_required_field(nil, field_name), do: {:error, "#{field_name} is required"}
  defp validate_required_field("", field_name), do: {:error, "#{field_name} is required"}
  defp validate_required_field(value, _field_name), do: {:ok, value}

  defp validate_uploaded_files(socket) do
    case socket.assigns.uploads.tar_file.entries do
      [] -> {:error, "Please upload a tar file"}
      [_entry | _] -> {:ok, consume_uploaded_entries(socket, :tar_file, &copy_upload/2)}
    end
  end

  defp copy_upload(%{path: temp_path}, _entry) do
    # Create a permanent location for the uploaded file
    dest_dir = Path.join([System.tmp_dir(), "elixihub_uploads"])
    File.mkdir_p!(dest_dir)
    
    dest_path = Path.join([dest_dir, "#{System.unique_integer()}.tar"])
    File.cp!(temp_path, dest_path)
    
    {:ok, dest_path}
  end

  defp deploy_application(app, [uploaded_file_path], _user) do
    try do
      IO.puts("Starting deployment for app: #{app.name}")
      
      # Get host configuration
      host = Hosts.get_host!(app.host_id)
      IO.puts("Host: #{host.name} (#{host.ip_address})")
      
      # Create SSH configuration
      ssh_config = Hosts.host_to_ssh_config(host)
      IO.puts("SSH config: #{inspect(ssh_config, limit: :infinity)}")
      
      # Update deployment log
      update_deployment_log(app, "connecting", "Connecting to #{host.name} (#{host.ip_address})")
      
      # Deploy the application
      IO.puts("Starting deployment with path: #{app.deploy_path}")
      case Deployment.deploy_app(ssh_config, uploaded_file_path, app.deploy_path, app) do
        {:ok, result} ->
          IO.puts("Deployment successful: #{inspect(result)}")
          Apps.update_app(app, %{
            deployment_status: "deployed",
            deployed_at: DateTime.utc_now(),
            deployment_log: Map.put(app.deployment_log || %{}, "success", "Deployment completed successfully: #{inspect(result)}")
          })
          
        {:error, reason} ->
          IO.puts("Deployment failed: #{inspect(reason)}")
          Apps.update_app(app, %{
            deployment_status: "failed",
            deployment_log: Map.put(app.deployment_log || %{}, "error", "Deployment failed: #{inspect(reason)}")
          })
      end
    rescue
      error ->
        IO.puts("Deployment exception: #{inspect(error, limit: :infinity)}")
        IO.puts("Stack trace: #{Exception.format(:error, error, __STACKTRACE__)}")
        
        Apps.update_app(app, %{
          deployment_status: "failed",
          deployment_log: Map.put(app.deployment_log || %{}, "exception", "Deployment failed with exception: #{inspect(error)}")
        })
    after
      # Clean up uploaded file
      File.rm(uploaded_file_path)
    end
  end

  defp update_deployment_log(app, step, message) do
    new_log = Map.put(app.deployment_log, step, message)
    Apps.update_app(app, %{deployment_log: new_log})
  end

  defp status_color("pending"), do: "bg-yellow-100 text-yellow-800"
  defp status_color("deploying"), do: "bg-blue-100 text-blue-800"
  defp status_color("deployed"), do: "bg-green-100 text-green-800"
  defp status_color("failed"), do: "bg-red-100 text-red-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end

  defp format_bytes(bytes) do
    cond do
      bytes >= 1024 * 1024 * 1024 -> 
        "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"
      bytes >= 1024 * 1024 -> 
        "#{Float.round(bytes / (1024 * 1024), 1)} MB"
      bytes >= 1024 -> 
        "#{Float.round(bytes / 1024, 1)} KB"
      true -> 
        "#{bytes} bytes"
    end
  end

  defp error_to_string(:too_large), do: "File too large (max 100MB)"
  defp error_to_string(:too_many_files), do: "Too many files (max 1)"
  defp error_to_string(:not_accepted), do: "File type not accepted (only .tar, .tgz, .tar.gz)"
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"

  defp maybe_set_default_deploy_path(app_params, app) do
    case {Map.get(app_params, "host_id"), Map.get(app_params, "deploy_path")} do
      {host_id, deploy_path} when not is_nil(host_id) and host_id != "" and (is_nil(deploy_path) or deploy_path == "") ->
        # Host is selected and deploy_path is empty, generate default
        try do
          host = Hosts.get_host!(host_id)
          ssh_username = host.ssh_username || "ubuntu"  # fallback to ubuntu if nil
          app_name = app.name |> String.downcase() |> String.replace(~r/[^a-z0-9_-]/, "_")
          default_path = "/home/#{ssh_username}/dev/#{app_name}"
          
          Map.put(app_params, "deploy_path", default_path)
        rescue
          _ ->
            # If host lookup fails, return original params
            app_params
        end
      
      _ ->
        # Either no host selected or deploy_path already has a value
        app_params
    end
  end
end