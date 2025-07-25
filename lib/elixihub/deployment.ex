defmodule Elixihub.Deployment do
  @moduledoc """
  The Deployment context for managing application deployments via SSH.
  """

  import Ecto.Query, warn: false
  alias Elixihub.Repo
  alias Elixihub.Apps.App
  alias Elixihub.Deployment.{SSHClient, TarHandler, AppInstaller, RoleParser, MCPParser}

  @doc """
  Deploys an application to a remote server via SSH.
  
  ## Parameters
  - ssh_config: SSH configuration map
  - tar_path: Path to the tar file to deploy  
  - deploy_path: Remote path where app should be deployed
  - app: The app being deployed
  
  ## Returns
  - {:ok, deployment_log} on success
  - {:error, reason} on failure
  """
  def deploy_app(ssh_config, tar_path, deploy_path, %App{} = app) when is_map(ssh_config) do
    deploy_app(ssh_config, tar_path, deploy_path, app, nil)
  end

  def deploy_app(ssh_config, tar_path, deploy_path, %App{} = app, host_architecture) when is_map(ssh_config) do
    full_ssh_config = Map.put(ssh_config, :deploy_path, deploy_path)
    
    with {:ok, _} <- validate_tar_file(tar_path),
         {:ok, _} <- validate_ssh_config(full_ssh_config),
         {:ok, _} <- update_deployment_status(app, "deploying"),
         {:ok, conn} <- SSHClient.connect(ssh_config),
         {:ok, _} <- stop_existing_service_if_running(conn, app, host_architecture),
         {:ok, _} <- TarHandler.upload_and_extract(conn, tar_path, deploy_path),
         {:ok, roles} <- RoleParser.extract_roles(conn, deploy_path),
         {:ok, _} <- sync_app_roles(app, roles),
         {:ok, result} <- AppInstaller.install_app(conn, app, deploy_path, host_architecture),
         {:ok, _} <- register_mcp_server(app, conn, deploy_path),
         {:ok, _} <- SSHClient.disconnect(conn),
         {:ok, _} <- update_deployment_status(app, "deployed") do
      log_deployment_success(app, result)
      {:ok, result}
    else
      {:error, reason} = error ->
        update_deployment_status(app, "failed")
        log_deployment_error(app, reason)
        error
    end
  end

  @doc """
  Deploys an application to a remote server via SSH (legacy signature).
  
  ## Parameters
  - app: The app to deploy
  - tar_path: Path to the tar file to deploy
  - ssh_config: SSH configuration map with keys:
    - host: Target server hostname/IP
    - port: SSH port (default: 22)
    - username: SSH username
    - password: SSH password (optional if using key)
    - private_key: SSH private key path (optional)
    - deploy_path: Remote path where app should be deployed
  
  ## Returns
  - {:ok, deployment_log} on success
  - {:error, reason} on failure
  """
  def deploy_app(%App{} = app, tar_path, ssh_config) when is_map(ssh_config) do
    deploy_app(app, tar_path, ssh_config, nil)
  end

  def deploy_app(%App{} = app, tar_path, ssh_config, host_architecture) when is_map(ssh_config) do
    with {:ok, _} <- validate_tar_file(tar_path),
         {:ok, _} <- validate_ssh_config(ssh_config),
         {:ok, _} <- update_deployment_status(app, "deploying"),
         {:ok, conn} <- SSHClient.connect(ssh_config),
         {:ok, _} <- stop_existing_service_if_running(conn, app, host_architecture),
         {:ok, _} <- TarHandler.upload_and_extract(conn, tar_path, ssh_config.deploy_path),
         {:ok, roles} <- RoleParser.extract_roles(conn, ssh_config.deploy_path),
         {:ok, _} <- sync_app_roles(app, roles),
         {:ok, result} <- AppInstaller.install_app(conn, app, ssh_config.deploy_path, host_architecture),
         {:ok, _} <- register_mcp_server(app, conn, ssh_config.deploy_path),
         {:ok, _} <- SSHClient.disconnect(conn),
         {:ok, _} <- update_deployment_status(app, "deployed") do
      log_deployment_success(app, result)
      {:ok, result}
    else
      {:error, reason} = error ->
        update_deployment_status(app, "failed")
        log_deployment_error(app, reason)
        error
    end
  end

  @doc """
  Undeploys an application from a remote server via SSH.
  
  ## Parameters
  - app: The app to undeploy
  - ssh_config: SSH configuration map
  
  ## Returns
  - {:ok, undeploy_result} on success
  - {:error, reason} on failure
  """
  def undeploy_app(%App{} = app, ssh_config) when is_map(ssh_config) do
    undeploy_app(app, ssh_config, nil)
  end

  def undeploy_app(%App{} = app, ssh_config, host_architecture) when is_map(ssh_config) do
    # Use the actual deployment path that was stored during deployment
    extract_path = app.deploy_path || AppInstaller.get_deployment_path(app)
    
    IO.puts("Starting undeployment for app: #{app.name}")
    IO.puts("Using extract_path: #{extract_path}")
    IO.puts("SSH config: #{inspect(ssh_config)}")
    IO.puts("Host architecture: #{host_architecture}")
    
    with {:ok, _} <- validate_ssh_config_for_undeploy(ssh_config),
         {:ok, _} <- update_deployment_status(app, "undeploying"),
         {:ok, conn} <- SSHClient.connect(ssh_config),
         {:ok, result} <- AppInstaller.undeploy_app(conn, app, extract_path, host_architecture),
         {:ok, _} <- SSHClient.disconnect(conn),
         {:ok, _} <- unregister_mcp_server(app),
         {:ok, _} <- update_deployment_status(app, "pending") do
      log_undeployment_success(app, result)
      {:ok, result}
    else
      {:error, reason} = error ->
        IO.puts("Undeployment failed: #{inspect(reason)}")
        update_deployment_status(app, "failed")
        log_undeployment_error(app, reason)
        error
    end
  end

  @doc """
  Updates the deployment status of an app.
  """
  def update_deployment_status(%App{} = app, status) do
    Elixihub.Apps.update_app(app, %{
      deployment_status: status,
      deployed_at: if(status == "deployed", do: DateTime.utc_now(), else: app.deployed_at)
    })
  end

  @doc """
  Gets the deployment log for an app.
  """
  def get_deployment_log(%App{} = app) do
    case app.deployment_log do
      log when is_list(log) -> log
      log when is_map(log) -> 
        # Convert map to list format for backwards compatibility
        Enum.map(log, fn {step, message} -> 
          %{step: step, message: message, timestamp: DateTime.utc_now(), level: :info}
        end)
      _ -> []
    end
  end

  @doc """
  Adds an entry to the deployment log.
  """
  def add_deployment_log(%App{} = app, entry) do
    current_log = case app.deployment_log do
      log when is_list(log) -> log
      log when is_map(log) -> 
        # Convert existing map to list format
        Enum.map(log, fn {step, message} -> 
          %{step: step, message: message, timestamp: DateTime.utc_now(), level: :info}
        end)
      _ -> []
    end
    
    new_log = current_log ++ [%{
      timestamp: DateTime.utc_now(),
      message: entry,
      level: :info
    }]
    
    Elixihub.Apps.update_app(app, %{deployment_log: new_log})
  end

  @doc """
  Validates SSH configuration.
  """
  def validate_ssh_config(config) do
    required_keys = [:host, :username, :deploy_path]
    
    case Enum.find(required_keys, fn key -> not Map.has_key?(config, key) end) do
      nil -> 
        if Map.has_key?(config, :password) or Map.has_key?(config, :private_key) do
          {:ok, config}
        else
          {:error, "Either password or private_key must be provided"}
        end
      missing_key -> 
        {:error, "Missing required SSH config key: #{missing_key}"}
    end
  end

  @doc """
  Validates SSH configuration for undeployment (doesn't require deploy_path).
  """
  def validate_ssh_config_for_undeploy(config) do
    required_keys = [:host, :username]
    
    case Enum.find(required_keys, fn key -> not Map.has_key?(config, key) end) do
      nil -> 
        if Map.has_key?(config, :password) or Map.has_key?(config, :private_key) do
          {:ok, config}
        else
          {:error, "Either password or private_key must be provided"}
        end
      missing_key -> 
        {:error, "Missing required SSH config key: #{missing_key}"}
    end
  end

  @doc """
  Validates that the tar file exists and is readable.
  """
  def validate_tar_file(tar_path) do
    case File.stat(tar_path) do
      {:ok, %File.Stat{type: :regular}} ->
        {:ok, tar_path}
      {:ok, %File.Stat{type: type}} ->
        {:error, "Expected regular file, got #{type}"}
      {:error, reason} ->
        {:error, "Cannot access tar file: #{inspect(reason)}"}
    end
  end

  @doc """
  Lists all apps with their deployment status.
  """
  def list_apps_with_deployment_status do
    from(a in App, select: [a.id, a.name, a.deployment_status, a.deployed_at])
    |> Repo.all()
  end

  @doc """
  Gets deployment statistics.
  """
  def get_deployment_stats do
    query = from(a in App, 
      group_by: a.deployment_status,
      select: {a.deployment_status, count(a.id)}
    )
    
    Repo.all(query)
    |> Enum.into(%{})
  end

  # Private functions

  defp sync_app_roles(%App{} = app, roles) when is_list(roles) do
    # Sync to app_roles table only - app roles should not be system roles
    case Elixihub.Apps.sync_app_roles(app.id, roles) do
      {:ok, _} -> 
        add_deployment_log(app, "Synced #{length(roles)} app role(s): #{Enum.map(roles, & &1.name) |> Enum.join(", ")}")
        {:ok, :roles_synced}
        
      {:error, reason} ->
        add_deployment_log(app, "Failed to sync app roles: #{inspect(reason)}")
        {:error, reason}
    end
  end


  defp log_deployment_success(app, result) do
    add_deployment_log(app, "Deployment completed successfully: #{inspect(result)}")
  end

  defp log_deployment_error(app, reason) do
    add_deployment_log(app, "Deployment failed: #{inspect(reason)}")
  end

  defp log_undeployment_success(app, result) do
    add_deployment_log(app, "Undeployment completed successfully: #{inspect(result)}")
  end

  defp log_undeployment_error(app, reason) do
    add_deployment_log(app, "Undeployment failed: #{inspect(reason)}")
  end

  defp register_mcp_server(app, connection, deploy_path) do
    case MCPParser.extract_mcp_info(connection, deploy_path, app) do
      {:ok, mcp_config} ->
        tools = Map.get(mcp_config, :tools, [])
        case Elixihub.MCP.register_mcp_server_for_app(app, mcp_config, tools) do
          {:ok, server} ->
            server_name = Map.get(server, :name, "unknown")
            tools_count = case Map.get(server, :tools, []) do
              tools when is_list(tools) -> length(tools)
              _ -> 0
            end
            add_deployment_log(app, "Registered MCP server: #{server_name} with #{tools_count} tools")
            {:ok, :mcp_registered}
          {:error, reason} ->
            add_deployment_log(app, "Failed to register MCP server: #{inspect(reason)}")
            {:ok, :mcp_registration_failed}  # Don't fail deployment for this
        end
      {:error, reason} ->
        add_deployment_log(app, "No MCP configuration found: #{inspect(reason)}")
        {:ok, :no_mcp_config}
    end
  end

  defp unregister_mcp_server(app) do
    case Elixihub.MCP.unregister_mcp_server_for_app(app) do
      {:ok, _} ->
        add_deployment_log(app, "Unregistered MCP server for app: #{app.name}")
        {:ok, :mcp_unregistered}
      {:error, reason} ->
        add_deployment_log(app, "Failed to unregister MCP server: #{inspect(reason)}")
        {:ok, :mcp_unregistration_failed}  # Don't fail undeployment for this
    end
  end

  defp stop_existing_service_if_running(connection, app, host_architecture \\ nil) do
    add_deployment_log(app, "Checking for existing running service...")
    
    case AppInstaller.get_app_service_status(connection, app, host_architecture) do
      {:ok, "active"} ->
        add_deployment_log(app, "Found active service. Stopping existing service before deployment...")
        case AppInstaller.stop_app_service(connection, app, host_architecture) do
          {:ok, :stopped} ->
            add_deployment_log(app, "Successfully stopped existing service")
            # Wait a moment for the service to fully stop
            :timer.sleep(3000)
            {:ok, :service_stopped}
          
          {:error, reason} ->
            add_deployment_log(app, "Failed to stop existing service: #{inspect(reason)}")
            {:error, "Failed to stop existing service: #{inspect(reason)}"}
        end
      
      {:ok, "activating"} ->
        add_deployment_log(app, "Found service in activating state. Stopping...")
        case AppInstaller.stop_app_service(connection, app, host_architecture) do
          {:ok, :stopped} ->
            add_deployment_log(app, "Successfully stopped activating service")
            :timer.sleep(3000)
            {:ok, :service_stopped}
          
          {:error, reason} ->
            add_deployment_log(app, "Failed to stop activating service: #{inspect(reason)}")
            {:error, "Failed to stop activating service: #{inspect(reason)}"}
        end
      
      {:ok, "failed"} ->
        add_deployment_log(app, "Found failed service. Attempting to stop...")
        case AppInstaller.stop_app_service(connection, app) do
          {:ok, :stopped} ->
            add_deployment_log(app, "Successfully stopped failed service")
            {:ok, :service_stopped}
          
          {:error, reason} ->
            add_deployment_log(app, "Warning: Could not stop failed service: #{inspect(reason)}")
            {:ok, :service_was_failed}  # Don't fail deployment for this
        end
      
      {:ok, "inactive"} ->
        add_deployment_log(app, "Service is inactive, no need to stop")
        {:ok, :service_already_stopped}
      
      {:ok, status} ->
        add_deployment_log(app, "Service status: #{status}. Attempting to stop as precaution...")
        case AppInstaller.stop_app_service(connection, app) do
          {:ok, :stopped} ->
            add_deployment_log(app, "Successfully stopped service (was #{status})")
            {:ok, :service_stopped}
          
          {:error, reason} ->
            add_deployment_log(app, "Warning: Could not stop service in #{status} state: #{inspect(reason)}")
            {:ok, :service_stop_warning}  # Don't fail deployment for this
        end
      
      {:error, reason} ->
        # Service probably doesn't exist yet - this is fine for new deployments
        add_deployment_log(app, "Could not check service status (likely first deployment): #{inspect(reason)}")
        {:ok, :no_existing_service}
    end
  end
end