defmodule Elixihub.Deployment.AppInstaller do
  @moduledoc """
  Handles application installation on remote servers.
  """

  alias Elixihub.Deployment.SSHClient
  alias Elixihub.Apps.App

  @doc """
  Installs an application on the remote server.
  
  ## Parameters
  - connection: SSH connection
  - app: App struct with installation details
  - extract_path: Path where the tar was extracted
  
  ## Returns
  - {:ok, installation_result} on success
  - {:error, reason} on failure
  """
  def install_app(connection, %App{} = app, extract_path) do
    with {:ok, app_type} <- detect_app_type(connection, extract_path),
         {:ok, _} <- prepare_installation_environment(connection, extract_path),
         {:ok, result} <- install_by_app_type(connection, app_type, extract_path, app),
         {:ok, _} <- configure_app_service(connection, app, extract_path),
         {:ok, _} <- start_app_service(connection, app) do
      {:ok, %{
        app_type: app_type,
        install_path: extract_path,
        service_status: :started,
        installation_log: result
      }}
    else
      {:error, reason} = error ->
        cleanup_failed_installation(connection, extract_path, app)
        error
    end
  end

  @doc """
  Detects the type of application from the extracted files.
  """
  def detect_app_type(connection, extract_path) do
    detection_checks = [
      {"elixir", "mix.exs"},
      {"node", "package.json"},
      {"python", "requirements.txt"},
      {"python", "setup.py"},
      {"ruby", "Gemfile"},
      {"go", "go.mod"},
      {"java", "pom.xml"},
      {"java", "build.gradle"},
      {"php", "composer.json"},
      {"generic", "Dockerfile"}
    ]
    
    detect_app_from_checks(connection, extract_path, detection_checks)
  end

  @doc """
  Stops an application service.
  """
  def stop_app_service(connection, %App{} = app) do
    service_name = get_service_name(app)
    
    case SSHClient.execute_command(connection, "systemctl stop #{service_name}") do
      {:ok, {_, _, 0}} ->
        {:ok, :stopped}
      
      {:ok, {_, error, exit_code}} ->
        {:error, "Failed to stop service (exit #{exit_code}): #{error}"}
      
      {:error, reason} ->
        {:error, "Failed to stop service: #{reason}"}
    end
  end

  @doc """
  Gets the status of an application service.
  """
  def get_app_service_status(connection, %App{} = app) do
    service_name = get_service_name(app)
    
    case SSHClient.execute_command(connection, "systemctl is-active #{service_name}") do
      {:ok, {status, _, 0}} ->
        {:ok, String.trim(status)}
      
      {:ok, {status, _, _}} ->
        {:ok, String.trim(status)}
      
      {:error, reason} ->
        {:error, "Failed to get service status: #{reason}"}
    end
  end

  @doc """
  Restarts an application service.
  """
  def restart_app_service(connection, %App{} = app) do
    service_name = get_service_name(app)
    
    case SSHClient.execute_command(connection, "systemctl restart #{service_name}") do
      {:ok, {_, _, 0}} ->
        {:ok, :restarted}
      
      {:ok, {_, error, exit_code}} ->
        {:error, "Failed to restart service (exit #{exit_code}): #{error}"}
      
      {:error, reason} ->
        {:error, "Failed to restart service: #{reason}"}
    end
  end

  # Private functions

  defp detect_app_from_checks(connection, extract_path, []) do
    {:ok, "generic"}
  end

  defp detect_app_from_checks(connection, extract_path, [{app_type, file} | rest]) do
    file_path = Path.join(extract_path, file)
    
    if SSHClient.path_exists?(connection, file_path) do
      {:ok, app_type}
    else
      detect_app_from_checks(connection, extract_path, rest)
    end
  end

  defp prepare_installation_environment(connection, extract_path) do
    commands = [
      "cd #{extract_path}",
      "chmod +x #{extract_path}",
      "find #{extract_path} -type f -name '*.sh' -exec chmod +x {} \\;"
    ]
    
    execute_commands_sequence(connection, commands)
  end

  defp install_by_app_type(connection, app_type, extract_path, app) do
    case app_type do
      "elixir" -> install_elixir_app(connection, extract_path, app)
      "node" -> install_node_app(connection, extract_path, app)
      "python" -> install_python_app(connection, extract_path, app)
      "ruby" -> install_ruby_app(connection, extract_path, app)
      "go" -> install_go_app(connection, extract_path, app)
      "java" -> install_java_app(connection, extract_path, app)
      "php" -> install_php_app(connection, extract_path, app)
      "generic" -> install_generic_app(connection, extract_path, app)
      _ -> {:error, "Unsupported application type: #{app_type}"}
    end
  end

  defp install_elixir_app(connection, extract_path, app) do
    commands = [
      "cd #{extract_path}",
      "mix local.hex --force",
      "mix local.rebar --force",
      "mix deps.get --only prod",
      "MIX_ENV=prod mix compile",
      "MIX_ENV=prod mix assets.deploy 2>/dev/null || echo 'No assets to deploy'",
      "MIX_ENV=prod mix release --overwrite"
    ]
    
    execute_commands_sequence(connection, commands)
  end

  defp install_node_app(connection, extract_path, app) do
    commands = [
      "cd #{extract_path}",
      "npm ci --only=production",
      "npm run build 2>/dev/null || echo 'No build script found'"
    ]
    
    execute_commands_sequence(connection, commands)
  end

  defp install_python_app(connection, extract_path, app) do
    commands = [
      "cd #{extract_path}",
      "python3 -m venv venv",
      "source venv/bin/activate",
      "pip install -r requirements.txt"
    ]
    
    execute_commands_sequence(connection, commands)
  end

  defp install_ruby_app(connection, extract_path, app) do
    commands = [
      "cd #{extract_path}",
      "bundle install --deployment --without development test"
    ]
    
    execute_commands_sequence(connection, commands)
  end

  defp install_go_app(connection, extract_path, app) do
    commands = [
      "cd #{extract_path}",
      "go mod download",
      "go build -o app ."
    ]
    
    execute_commands_sequence(connection, commands)
  end

  defp install_java_app(connection, extract_path, app) do
    cond do
      SSHClient.path_exists?(connection, Path.join(extract_path, "pom.xml")) ->
        execute_commands_sequence(connection, [
          "cd #{extract_path}",
          "mvn clean package -DskipTests"
        ])
      
      SSHClient.path_exists?(connection, Path.join(extract_path, "build.gradle")) ->
        execute_commands_sequence(connection, [
          "cd #{extract_path}",
          "./gradlew build -x test"
        ])
      
      true ->
        {:error, "No supported Java build file found"}
    end
  end

  defp install_php_app(connection, extract_path, app) do
    commands = [
      "cd #{extract_path}",
      "composer install --no-dev --optimize-autoloader"
    ]
    
    execute_commands_sequence(connection, commands)
  end

  defp install_generic_app(connection, extract_path, app) do
    # Check for common installation scripts
    install_script_path = Path.join(extract_path, "install.sh")
    
    if SSHClient.path_exists?(connection, install_script_path) do
      execute_commands_sequence(connection, [
        "cd #{extract_path}",
        "chmod +x install.sh",
        "./install.sh"
      ])
    else
      {:ok, "Generic app deployed - no installation script found"}
    end
  end

  defp configure_app_service(connection, app, extract_path) do
    service_name = get_service_name(app)
    service_file = generate_systemd_service(app, extract_path)
    service_path = "/etc/systemd/system/#{service_name}.service"
    
    # Write service file
    case write_service_file(connection, service_file, service_path) do
      {:ok, _} ->
        # Reload systemd and enable service
        execute_commands_sequence(connection, [
          "systemctl daemon-reload",
          "systemctl enable #{service_name}"
        ])
      
      {:error, reason} ->
        {:error, "Failed to configure service: #{reason}"}
    end
  end

  defp start_app_service(connection, app) do
    service_name = get_service_name(app)
    
    case SSHClient.execute_command(connection, "systemctl start #{service_name}") do
      {:ok, {_, _, 0}} ->
        # Wait a moment and check if service is running
        :timer.sleep(2000)
        get_app_service_status(connection, app)
      
      {:ok, {_, error, exit_code}} ->
        {:error, "Failed to start service (exit #{exit_code}): #{error}"}
      
      {:error, reason} ->
        {:error, "Failed to start service: #{reason}"}
    end
  end

  defp cleanup_failed_installation(connection, extract_path, app) do
    service_name = get_service_name(app)
    
    # Stop and remove service if it exists
    SSHClient.execute_command(connection, "systemctl stop #{service_name} 2>/dev/null || true")
    SSHClient.execute_command(connection, "systemctl disable #{service_name} 2>/dev/null || true")
    SSHClient.execute_command(connection, "rm -f /etc/systemd/system/#{service_name}.service")
    SSHClient.execute_command(connection, "systemctl daemon-reload")
    
    # Remove installation directory
    SSHClient.execute_command(connection, "rm -rf #{extract_path}")
  end

  defp execute_commands_sequence(connection, commands) do
    results = Enum.map(commands, fn command ->
      case SSHClient.execute_command(connection, command) do
        {:ok, {stdout, stderr, exit_code}} ->
          %{
            command: command,
            stdout: stdout,
            stderr: stderr,
            exit_code: exit_code,
            success: exit_code == 0
          }
        
        {:error, reason} ->
          %{
            command: command,
            error: reason,
            success: false
          }
      end
    end)
    
    failed_commands = Enum.filter(results, fn result -> not result.success end)
    
    if Enum.empty?(failed_commands) do
      {:ok, results}
    else
      {:error, "Commands failed: #{inspect(failed_commands)}"}
    end
  end

  defp get_service_name(app) do
    "elixihub-#{app.name}" |> String.downcase() |> String.replace(~r/[^a-z0-9-]/, "-")
  end

  defp generate_systemd_service(app, extract_path) do
    service_name = get_service_name(app)
    
    """
    [Unit]
    Description=ElixiHub App: #{app.name}
    After=network.target

    [Service]
    Type=simple
    User=elixihub
    Group=elixihub
    WorkingDirectory=#{extract_path}
    ExecStart=#{get_start_command(extract_path)}
    Restart=always
    RestartSec=5
    Environment=PORT=#{app.ssh_port || 4000}
    Environment=MIX_ENV=prod

    [Install]
    WantedBy=multi-user.target
    """
  end

  defp get_start_command(extract_path) do
    # Try to detect the appropriate start command
    cond do
      File.exists?(Path.join(extract_path, "_build/prod/rel")) ->
        # Elixir release
        release_name = extract_path |> Path.basename()
        "#{extract_path}/_build/prod/rel/#{release_name}/bin/#{release_name} start"
      
      File.exists?(Path.join(extract_path, "package.json")) ->
        # Node.js app
        "#{extract_path}/node_modules/.bin/node #{extract_path}/index.js"
      
      File.exists?(Path.join(extract_path, "app")) ->
        # Go binary
        "#{extract_path}/app"
      
      true ->
        # Generic
        "#{extract_path}/start.sh"
    end
  end

  defp write_service_file(connection, content, path) do
    temp_file = "/tmp/service_#{:rand.uniform(10000)}"
    
    case :file.write_file(temp_file, content) do
      :ok ->
        case SSHClient.upload_file(connection, temp_file, path) do
          {:ok, _} ->
            File.rm(temp_file)
            {:ok, path}
          
          {:error, reason} ->
            File.rm(temp_file)
            {:error, reason}
        end
      
      {:error, reason} ->
        {:error, "Failed to write temp service file: #{inspect(reason)}"}
    end
  end
end