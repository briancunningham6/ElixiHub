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

  defp apply_action(socket, :deploy, %{"id" => id}) do
    app = Apps.get_app!(id) |> Elixihub.Repo.preload(:node)
    socket
    |> assign(:page_title, "Deploy Application")
    |> assign(:app, app)
  end

  defp apply_action(socket, :deploy_select, _params) do
    socket
    |> assign(:page_title, "Select App to Deploy")
    |> assign(:app, nil)
  end

  @impl true
  def handle_info({ElixihubWeb.Admin.AppLive.FormComponent, {:saved, _app}}, socket) do
    {:noreply, assign(socket, :apps, Apps.list_apps())}
  end

  @impl true
  def handle_info({:deployment_complete, app_id, status, result}, socket) do
    # Refresh the apps list to show updated deployment status
    {:noreply, 
     socket
     |> assign(:apps, Apps.list_apps())
     |> put_flash(case status do
       :success -> :info
       :error -> :error
     end, case status do
       :success -> "Deployment completed successfully!"
       :error -> "Deployment failed: #{inspect(result)}"
     end)
    }
  end

  @impl true
  def handle_info({:select_app_for_deploy, app_id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/apps/#{app_id}/deploy")}
  end

  @impl true
  def handle_info({:undeployment_complete, app_id, status, result}, socket) do
    # Refresh the apps list to show updated deployment status
    {:noreply, 
     socket
     |> assign(:apps, Apps.list_apps())
     |> put_flash(case status do
       :success -> :info
       :error -> :error
     end, case status do
       :success -> "Undeployment completed successfully!"
       :error -> "Undeployment failed: #{inspect(result)}"
     end)
    }
  end

  @impl true
  def handle_info({:undeploy_and_delete_complete, app_name, status, result}, socket) do
    # Refresh the apps list to show the app has been deleted
    {:noreply, 
     socket
     |> assign(:apps, Apps.list_apps())
     |> put_flash(case status do
       :success -> :info
       :error -> :error
     end, case status do
       :success -> "#{app_name} undeployed and deleted successfully!"
       :error -> "Failed to undeploy and delete #{app_name}: #{inspect(result)}"
     end)
    }
  end

  # Private function to perform undeployment in background
  defp perform_undeployment(app, user, parent_pid) do
    case get_ssh_config(app) do
      {:ok, ssh_config} ->
        case Elixihub.Deployment.undeploy_app(app, ssh_config) do
          {:ok, result} ->
            send(parent_pid, {:undeployment_complete, app.id, :success, result})
          {:error, reason} ->
            send(parent_pid, {:undeployment_complete, app.id, :error, reason})
        end
      
      {:error, reason} ->
        send(parent_pid, {:undeployment_complete, app.id, :error, reason})
    end
  end

  defp get_ssh_config(app) do
    cond do
      # Prefer host configuration (used in modern deployments)
      app.host ->
        {:ok, Elixihub.Hosts.host_to_ssh_config(app.host)}
      
      # Fallback to node configuration (legacy)
      app.node ->
        ssh_config = %{
          host: app.node.host,
          port: app.node.port || 22,
          username: app.node.username,
          password: app.node.password
        }
        |> maybe_add_private_key(app.node.private_key)
        
        {:ok, ssh_config}
      
      true ->
        {:error, "No host or node configuration found"}
    end
  end

  defp maybe_add_private_key(ssh_config, nil), do: ssh_config
  defp maybe_add_private_key(ssh_config, private_key) do
    Map.put(ssh_config, :private_key, private_key)
  end

  # Private function to perform undeployment followed by deletion
  defp perform_undeploy_and_delete(app, user, parent_pid) do
    app_name = app.name
    
    case get_ssh_config(app) do
      {:ok, ssh_config} ->
        case Elixihub.Deployment.undeploy_app(app, ssh_config) do
          {:ok, _undeploy_result} ->
            # Undeployment successful, now delete the app record
            case Elixihub.Apps.delete_app(app) do
              {:ok, _} ->
                send(parent_pid, {:undeploy_and_delete_complete, app_name, :success, "App undeployed and deleted"})
              {:error, reason} ->
                send(parent_pid, {:undeploy_and_delete_complete, app_name, :error, "Undeployed but failed to delete: #{inspect(reason)}"})
            end
          
          {:error, reason} ->
            # Undeployment failed, still try to delete the app record
            case Elixihub.Apps.delete_app(app) do
              {:ok, _} ->
                send(parent_pid, {:undeploy_and_delete_complete, app_name, :error, "Failed to undeploy but deleted app record: #{inspect(reason)}"})
              {:error, delete_reason} ->
                send(parent_pid, {:undeploy_and_delete_complete, app_name, :error, "Failed to undeploy AND delete: undeploy error: #{inspect(reason)}, delete error: #{inspect(delete_reason)}"})
            end
        end
      
      {:error, reason} ->
        # Can't get SSH config, just delete the app record
        case Elixihub.Apps.delete_app(app) do
          {:ok, _} ->
            send(parent_pid, {:undeploy_and_delete_complete, app_name, :error, "No SSH config available but deleted app record: #{reason}"})
          {:error, delete_reason} ->
            send(parent_pid, {:undeploy_and_delete_complete, app_name, :error, "No SSH config and failed to delete: #{inspect(delete_reason)}"})
        end
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    app = Apps.get_app!(id) |> Elixihub.Repo.preload([:node, :host])
    
    case app.deployment_status do
      "deployed" ->
        # App is deployed, need to undeploy first
        if app.host || app.node do
          # Start undeployment and deletion in background
          parent_pid = self()
          spawn(fn -> perform_undeploy_and_delete(app, socket.assigns.current_user, parent_pid) end)
          
          {:noreply,
           socket
           |> assign(:apps, Apps.list_apps())
           |> put_flash(:info, "Undeploying and deleting #{app.name}...")
          }
        else
          # No host/node config, just delete the app record
          {:ok, _} = Apps.delete_app(app)
          
          {:noreply,
           socket
           |> assign(:apps, Apps.list_apps())
           |> put_flash(:info, "Application deleted successfully")
          }
        end
      
      _ ->
        # App is not deployed, delete directly
        {:ok, _} = Apps.delete_app(app)

        {:noreply, 
         socket
         |> assign(:apps, Apps.list_apps())
         |> put_flash(:info, "Application deleted successfully")
        }
    end
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
  def handle_event("undeploy", %{"id" => id}, socket) do
    app = Apps.get_app!(id) |> Elixihub.Repo.preload([:node, :host])
    
    if app.deployment_status == "deployed" and (app.host || app.node) do
      # Start undeployment in background
      parent_pid = self()
      spawn(fn -> perform_undeployment(app, socket.assigns.current_user, parent_pid) end)
      
      {:noreply,
       socket
       |> assign(:apps, Apps.list_apps())
       |> put_flash(:info, "Undeployment started for #{app.name}")
      }
    else
      {:noreply,
       socket
       |> put_flash(:error, "Application is not deployed or has no assigned host/node")
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
              <h1 class="text-3xl font-bold text-gray-900 mt-2">Manage Applications</h1>
              <p class="mt-1 text-sm text-gray-500">Register and configure external applications</p>
            </div>
            <div class="flex space-x-3">
              <.link
                patch={~p"/admin/apps/new"}
                class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
              >
                Register New App
              </.link>
              <.link
                patch={~p"/admin/apps/deploy"}
                class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
              >
                Deploy App
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
                  <div :if={app.deployment_status != "pending"} class="text-xs mt-1">
                    <span class="text-gray-500">Deployment:</span>
                    <span class={[
                      "ml-1 inline-flex items-center px-1.5 py-0.5 rounded-full text-xs font-medium",
                      case app.deployment_status do
                        "deployed" -> "bg-green-100 text-green-800"
                        "deploying" -> "bg-blue-100 text-blue-800"
                        "undeploying" -> "bg-orange-100 text-orange-800"
                        "failed" -> "bg-red-100 text-red-800"
                        _ -> "bg-gray-100 text-gray-800"
                      end
                    ]}>
                      <%= String.capitalize(app.deployment_status || "pending") %>
                    </span>
                    <span :if={app.deployed_at} class="ml-1 text-gray-400">
                      on <%= Calendar.strftime(app.deployed_at, "%m/%d/%y") %>
                    </span>
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
                    patch={~p"/admin/apps/#{app}/deploy"}
                    class="text-purple-600 hover:text-purple-900 text-sm font-medium"
                  >
                    Deploy
                  </.link>
                  
                  <button
                    :if={app.deployment_status == "deployed"}
                    phx-click="undeploy"
                    phx-value-id={app.id}
                    data-confirm="Are you sure you want to undeploy this application? This will stop the service, remove all files, and delete the service."
                    class="text-orange-600 hover:text-orange-900 text-sm font-medium"
                  >
                    Undeploy
                  </button>
                  
                  <span
                    :if={app.deployment_status == "undeploying"}
                    class="text-orange-500 text-sm font-medium"
                  >
                    Undeploying...
                  </span>
                  
                  <.link
                    navigate={~p"/admin/apps/#{app}/roles"}
                    class="text-indigo-600 hover:text-indigo-900 text-sm font-medium"
                  >
                    Roles
                  </.link>
                  
                  <.link
                    patch={~p"/admin/apps/#{app}/edit"}
                    class="text-blue-600 hover:text-blue-900 text-sm font-medium"
                  >
                    Edit
                  </.link>
                  
                  <button
                    phx-click="delete"
                    phx-value-id={app.id}
                    data-confirm={if app.deployment_status == "deployed" do
                      "Are you sure you want to delete this application? This will first undeploy the application (stop service, remove files) and then delete the app record. This action cannot be undone."
                    else
                      "Are you sure you want to delete this application? This action cannot be undone."
                    end}
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

    <.modal
      :if={@live_action == :deploy}
      id="deploy-modal"
      show
      on_cancel={JS.patch(~p"/admin/apps")}
    >
      <.live_component
        module={ElixihubWeb.Admin.AppLive.DeploySimpleComponent}
        id={"deploy-#{@app.id}"}
        app={@app}
        current_user={@current_user}
        patch={~p"/admin/apps"}
      />
    </.modal>

    <.modal
      :if={@live_action == :deploy_select}
      id="deploy-select-modal"
      show
      on_cancel={JS.patch(~p"/admin/apps")}
    >
      <.live_component
        module={ElixihubWeb.Admin.AppLive.DeploySelectComponent}
        id="deploy-select"
        patch={~p"/admin/apps"}
      />
    </.modal>
    """
  end
end