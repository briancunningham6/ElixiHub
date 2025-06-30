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
    
    case SSHClient.execute_command(connection, "sudo systemctl stop #{service_name}") do
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
    
    case SSHClient.execute_command(connection, "sudo systemctl is-active #{service_name}") do
      {:ok, {status, _, 0}} ->
        {:ok, String.trim(status)}
      
      {:ok, {status, _, _}} ->
        {:ok, String.trim(status)}
      
      {:error, reason} ->
        {:error, "Failed to get service status: #{reason}"}
    end
  end

  @doc """
  Completely undeploys an application: stops service, removes files, deletes service.
  
  ## Parameters
  - connection: SSH connection
  - app: App struct with deployment details
  - extract_path: Path where the application was deployed
  
  ## Returns
  - {:ok, undeploy_result} on success
  - {:error, reason} on failure
  """
  def undeploy_app(connection, %App{} = app, extract_path) do
    service_name = get_service_name(app)
    service_path = "/etc/systemd/system/#{service_name}.service"
    
    IO.puts("Starting undeploy for app: #{app.name}")
    IO.puts("Service name: #{service_name}")
    IO.puts("Service path: #{service_path}")
    IO.puts("Extract path: #{extract_path}")
    
    undeployment_steps = [
      {"Stop service", fn -> stop_app_service(connection, app) end},
      {"Disable service", fn -> disable_app_service(connection, service_name) end},
      {"Remove service file", fn -> remove_service_file(connection, service_path) end},
      {"Reload systemd", fn -> reload_systemd(connection) end},
      {"Remove application files", fn -> remove_app_files(connection, extract_path) end}
    ]
    
    execute_undeployment_steps(undeployment_steps, [])
  end

  @doc """
  Gets the deployment path for an app.
  """
  def get_deployment_path(%App{} = app, base_path \\ "/home") do
    # Construct the deployment path based on app name and node info
    app_name = String.downcase(app.name) |> String.replace(~r/[^a-z0-9_-]/, "-")
    
    if app.node do
      case String.split(app.node.name, "@") do
        [username, _host] -> "#{base_path}/#{username}/dev/#{app_name}"
        _ -> "#{base_path}/#{app.node.name}/dev/#{app_name}"
      end
    else
      "#{base_path}/dev/#{app_name}"
    end
  end

  @doc """
  Restarts an application service.
  """
  def restart_app_service(connection, %App{} = app) do
    service_name = get_service_name(app)
    
    case SSHClient.execute_command(connection, "sudo systemctl restart #{service_name}") do
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
      "find #{extract_path} -type f -name '*.sh' -exec chmod +x {} \\;",
      "chmod +x #{extract_path}/bin/* 2>/dev/null || true",
      "find #{extract_path}/bin -type f -exec chmod +x {} \\; 2>/dev/null || true"
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
    # Always build on target architecture to avoid exec format errors
    try_elixir_installation_on_target(connection, extract_path)
  end
  
  defp try_elixir_installation_primary(connection, extract_path) do
    # Primary method with network optimizations
    combined_command = """
    cd #{extract_path} && \
    git config --global http.lowSpeedLimit 1000 && \
    git config --global http.lowSpeedTime 300 && \
    git config --global http.postBuffer 524288000 && \
    export HEX_HTTP_TIMEOUT=300 && \
    export HEX_HTTP_CONCURRENCY=1 && \
    mix local.hex --force && \
    mix local.rebar --force && \
    timeout 600 mix deps.get --only prod && \
    MIX_ENV=prod mix compile && \
    (MIX_ENV=prod mix assets.deploy 2>/dev/null || echo 'No assets to deploy') && \
    MIX_ENV=prod mix release --overwrite
    """
    
    case SSHClient.execute_deployment_command(connection, combined_command) do
      {:ok, {stdout, stderr, 0}} ->
        {:ok, [%{
          command: "elixir_build_sequence_primary",
          stdout: stdout,
          stderr: stderr,
          exit_code: 0,
          success: true
        }]}
      
      {:ok, {stdout, stderr, exit_code}} ->
        {:error, "Primary build failed (exit #{exit_code}): #{stderr}"}
      
      {:error, reason} ->
        {:error, "Primary build failed: #{inspect(reason)}"}
    end
  end
  
  defp try_elixir_installation_on_target(connection, extract_path) do
    # Build release on target architecture with better error handling
    IO.puts("Starting Elixir build on target architecture at: #{extract_path}")
    
    # Step 1: Environment check and setup
    setup_command = """
    cd #{extract_path} && \
    echo 'Building release on target architecture...' && \
    echo 'Available memory:' && \
    free -h && \
    echo 'Disk space:' && \
    df -h . && \
    git config --global http.lowSpeedLimit 1000 && \
    git config --global http.lowSpeedTime 300 && \
    git config --global http.postBuffer 524288000 && \
    export HEX_HTTP_TIMEOUT=300 && \
    export HEX_HTTP_CONCURRENCY=1 && \
    export ERL_MAX_PORTS=4096 && \
    export ELIXIR_ERL_OPTIONS="+K true +A 4" && \
    mix local.hex --force && \
    mix local.rebar --force && \
    echo 'Setup completed successfully'
    """
    
    case SSHClient.execute_elixir_build_command(connection, setup_command) do
      {:ok, {_stdout, _stderr, 0}} ->
        IO.puts("Environment setup completed successfully")
        # Continue with main build
        try_elixir_build_steps(connection, extract_path)
      
      {:ok, {stdout, stderr, exit_code}} ->
        {:error, "Environment setup failed (exit #{exit_code}): #{stderr}"}
      
      {:error, reason} ->
        {:error, "Environment setup failed: #{inspect(reason)}"}
    end
  end
  
  defp try_elixir_build_steps(connection, extract_path) do
    # Main build steps with increased timeout for compilation
    build_command = """
    cd #{extract_path} && \
    export HEX_HTTP_TIMEOUT=300 && \
    export HEX_HTTP_CONCURRENCY=1 && \
    export ERL_MAX_PORTS=4096 && \
    export ELIXIR_ERL_OPTIONS="+K true +A 4" && \
    echo 'Getting dependencies...' && \
    timeout 900 mix deps.get --only prod && \
    echo 'Compiling application...' && \
    timeout 1200 sh -c 'MIX_ENV=prod mix compile' && \
    echo 'Building assets...' && \
    (timeout 300 sh -c 'MIX_ENV=prod mix assets.deploy' 2>/dev/null || echo 'No assets to deploy') && \
    echo 'Creating release...' && \
    timeout 600 sh -c 'MIX_ENV=prod mix release --overwrite' && \
    echo 'Release built successfully on target architecture'
    """
    
    case SSHClient.execute_elixir_build_command(connection, build_command) do
      {:ok, {stdout, stderr, 0}} ->
        IO.puts("Elixir build completed successfully")
        {:ok, [%{
          command: "elixir_build_on_target",
          stdout: stdout,
          stderr: stderr,
          exit_code: 0,
          success: true
        }]}
      
      {:ok, {stdout, stderr, exit_code}} ->
        IO.puts("Elixir build failed with exit code: #{exit_code}")
        IO.puts("Last 1000 chars of stdout: #{String.slice(stdout, -1000, 1000)}")
        IO.puts("Last 1000 chars of stderr: #{String.slice(stderr, -1000, 1000)}")
        
        # Try low-memory build strategy if regular build failed
        if String.contains?(stderr, "killed") or String.contains?(stdout, "killed") or 
           String.contains?(stderr, "memory") or String.contains?(stderr, "out of memory") do
          IO.puts("Detected potential memory issue, trying low-memory build strategy...")
          try_elixir_low_memory_build(connection, extract_path)
        else
          {:error, "Elixir build failed (exit #{exit_code}). Check logs for details."}
        end
      
      {:error, reason} ->
        IO.puts("Elixir build failed with error: #{inspect(reason)}")
        {:error, "Elixir build failed: #{inspect(reason)}"}
    end
  end
  
  defp try_elixir_low_memory_build(connection, extract_path) do
    IO.puts("Attempting low-memory build strategy...")
    
    low_memory_command = """
    cd #{extract_path} && \
    export HEX_HTTP_TIMEOUT=300 && \
    export HEX_HTTP_CONCURRENCY=1 && \
    export ERL_MAX_PORTS=2048 && \
    export ELIXIR_ERL_OPTIONS="+K true +A 2" && \
    export ERL_FLAGS="+MBas aobf +MBlmbcs 512 +MHas aobf +MHlmbcs 512" && \
    echo 'Low-memory build: Getting dependencies...' && \
    timeout 900 mix deps.get --only prod && \
    echo 'Low-memory build: Compiling application with reduced parallelism...' && \
    timeout 1800 sh -c 'MIX_ENV=prod mix compile --force --no-optional-deps' && \
    echo 'Low-memory build: Building assets...' && \
    (timeout 300 sh -c 'MIX_ENV=prod mix assets.deploy' 2>/dev/null || echo 'No assets to deploy') && \
    echo 'Low-memory build: Creating release...' && \
    timeout 900 sh -c 'MIX_ENV=prod mix release --overwrite --no-optional-deps' && \
    echo 'Low-memory release built successfully'
    """
    
    case SSHClient.execute_elixir_build_command(connection, low_memory_command) do
      {:ok, {stdout, stderr, 0}} ->
        IO.puts("Low-memory Elixir build completed successfully")
        {:ok, [%{
          command: "elixir_low_memory_build",
          stdout: stdout,
          stderr: stderr,
          exit_code: 0,
          success: true
        }]}
      
      {:ok, {stdout, stderr, exit_code}} ->
        IO.puts("Low-memory build also failed with exit code: #{exit_code}")
        {:error, "Both regular and low-memory Elixir build failed (exit #{exit_code})."}
      
      {:error, reason} ->
        IO.puts("Low-memory build failed with error: #{inspect(reason)}")
        {:error, "Low-memory Elixir build failed: #{inspect(reason)}"}
    end
  end

  defp install_node_app(connection, extract_path, app) do
    combined_command = """
    cd #{extract_path} && \
    npm ci --only=production && \
    (npm run build 2>/dev/null || echo 'No build script found')
    """
    
    case SSHClient.execute_deployment_command(connection, combined_command) do
      {:ok, {stdout, stderr, 0}} ->
        {:ok, [%{
          command: "node_build_sequence",
          stdout: stdout,
          stderr: stderr,
          exit_code: 0,
          success: true
        }]}
      
      {:ok, {stdout, stderr, exit_code}} ->
        {:error, "Commands failed: [%{command: \"node_build_sequence\", stdout: \"#{stdout}\", stderr: \"#{stderr}\", success: false, exit_code: #{exit_code}}]"}
      
      {:error, reason} ->
        {:error, "Commands failed: [%{command: \"node_build_sequence\", error: #{inspect(reason)}, success: false}]"}
    end
  end

  defp install_python_app(connection, extract_path, app) do
    combined_command = """
    cd #{extract_path} && \
    python3 -m venv venv && \
    source venv/bin/activate && \
    pip install -r requirements.txt
    """
    
    case SSHClient.execute_deployment_command(connection, combined_command) do
      {:ok, {stdout, stderr, 0}} ->
        {:ok, [%{
          command: "python_build_sequence",
          stdout: stdout,
          stderr: stderr,
          exit_code: 0,
          success: true
        }]}
      
      {:ok, {stdout, stderr, exit_code}} ->
        {:error, "Commands failed: [%{command: \"python_build_sequence\", stdout: \"#{stdout}\", stderr: \"#{stderr}\", success: false, exit_code: #{exit_code}}]"}
      
      {:error, reason} ->
        {:error, "Commands failed: [%{command: \"python_build_sequence\", error: #{inspect(reason)}, success: false}]"}
    end
  end

  defp install_ruby_app(connection, extract_path, app) do
    combined_command = """
    cd #{extract_path} && \
    bundle install --deployment --without development test
    """
    
    case SSHClient.execute_deployment_command(connection, combined_command) do
      {:ok, {stdout, stderr, 0}} ->
        {:ok, [%{
          command: "ruby_build_sequence",
          stdout: stdout,
          stderr: stderr,
          exit_code: 0,
          success: true
        }]}
      
      {:ok, {stdout, stderr, exit_code}} ->
        {:error, "Commands failed: [%{command: \"ruby_build_sequence\", stdout: \"#{stdout}\", stderr: \"#{stderr}\", success: false, exit_code: #{exit_code}}]"}
      
      {:error, reason} ->
        {:error, "Commands failed: [%{command: \"ruby_build_sequence\", error: #{inspect(reason)}, success: false}]"}
    end
  end

  defp install_go_app(connection, extract_path, app) do
    combined_command = """
    cd #{extract_path} && \
    go mod download && \
    go build -o app .
    """
    
    case SSHClient.execute_deployment_command(connection, combined_command) do
      {:ok, {stdout, stderr, 0}} ->
        {:ok, [%{
          command: "go_build_sequence",
          stdout: stdout,
          stderr: stderr,
          exit_code: 0,
          success: true
        }]}
      
      {:ok, {stdout, stderr, exit_code}} ->
        {:error, "Commands failed: [%{command: \"go_build_sequence\", stdout: \"#{stdout}\", stderr: \"#{stderr}\", success: false, exit_code: #{exit_code}}]"}
      
      {:error, reason} ->
        {:error, "Commands failed: [%{command: \"go_build_sequence\", error: #{inspect(reason)}, success: false}]"}
    end
  end

  defp install_java_app(connection, extract_path, app) do
    cond do
      SSHClient.path_exists?(connection, Path.join(extract_path, "pom.xml")) ->
        combined_command = "cd #{extract_path} && mvn clean package -DskipTests"
        
        case SSHClient.execute_deployment_command(connection, combined_command) do
          {:ok, {stdout, stderr, 0}} ->
            {:ok, [%{
              command: "maven_build_sequence",
              stdout: stdout,
              stderr: stderr,
              exit_code: 0,
              success: true
            }]}
          
          {:ok, {stdout, stderr, exit_code}} ->
            {:error, "Commands failed: [%{command: \"maven_build_sequence\", stdout: \"#{stdout}\", stderr: \"#{stderr}\", success: false, exit_code: #{exit_code}}]"}
          
          {:error, reason} ->
            {:error, "Commands failed: [%{command: \"maven_build_sequence\", error: #{inspect(reason)}, success: false}]"}
        end
      
      SSHClient.path_exists?(connection, Path.join(extract_path, "build.gradle")) ->
        combined_command = "cd #{extract_path} && ./gradlew build -x test"
        
        case SSHClient.execute_deployment_command(connection, combined_command) do
          {:ok, {stdout, stderr, 0}} ->
            {:ok, [%{
              command: "gradle_build_sequence",
              stdout: stdout,
              stderr: stderr,
              exit_code: 0,
              success: true
            }]}
          
          {:ok, {stdout, stderr, exit_code}} ->
            {:error, "Commands failed: [%{command: \"gradle_build_sequence\", stdout: \"#{stdout}\", stderr: \"#{stderr}\", success: false, exit_code: #{exit_code}}]"}
          
          {:error, reason} ->
            {:error, "Commands failed: [%{command: \"gradle_build_sequence\", error: #{inspect(reason)}, success: false}]"}
        end
      
      true ->
        {:error, "No supported Java build file found"}
    end
  end

  defp install_php_app(connection, extract_path, app) do
    combined_command = """
    cd #{extract_path} && \
    composer install --no-dev --optimize-autoloader
    """
    
    case SSHClient.execute_deployment_command(connection, combined_command) do
      {:ok, {stdout, stderr, 0}} ->
        {:ok, [%{
          command: "php_build_sequence",
          stdout: stdout,
          stderr: stderr,
          exit_code: 0,
          success: true
        }]}
      
      {:ok, {stdout, stderr, exit_code}} ->
        {:error, "Commands failed: [%{command: \"php_build_sequence\", stdout: \"#{stdout}\", stderr: \"#{stderr}\", success: false, exit_code: #{exit_code}}]"}
      
      {:error, reason} ->
        {:error, "Commands failed: [%{command: \"php_build_sequence\", error: #{inspect(reason)}, success: false}]"}
    end
  end

  defp install_generic_app(connection, extract_path, app) do
    # Check for common installation scripts
    install_script_path = Path.join(extract_path, "install.sh")
    
    if SSHClient.path_exists?(connection, install_script_path) do
      combined_command = """
      cd #{extract_path} && \
      chmod +x install.sh && \
      ./install.sh
      """
      
      case SSHClient.execute_deployment_command(connection, combined_command) do
        {:ok, {stdout, stderr, 0}} ->
          {:ok, [%{
            command: "generic_install_sequence",
            stdout: stdout,
            stderr: stderr,
            exit_code: 0,
            success: true
          }]}
        
        {:ok, {stdout, stderr, exit_code}} ->
          {:error, "Commands failed: [%{command: \"generic_install_sequence\", stdout: \"#{stdout}\", stderr: \"#{stderr}\", success: false, exit_code: #{exit_code}}]"}
        
        {:error, reason} ->
          {:error, "Commands failed: [%{command: \"generic_install_sequence\", error: #{inspect(reason)}, success: false}]"}
      end
    else
      {:ok, [%{
        command: "generic_app_skip",
        stdout: "Generic app deployed - no installation script found",
        stderr: "",
        exit_code: 0,
        success: true
      }]}
    end
  end

  defp configure_app_service(connection, app, extract_path) do
    service_name = get_service_name(app)
    service_file = generate_systemd_service(app, extract_path, connection)
    service_path = "/etc/systemd/system/#{service_name}.service"
    
    # Write service file using sudo
    case write_service_file_with_sudo(connection, service_file, service_path) do
      {:ok, _} ->
        # Reload systemd and enable service
        execute_commands_sequence(connection, [
          "sudo systemctl daemon-reload",
          "sudo systemctl enable #{service_name}"
        ])
      
      {:error, reason} ->
        {:error, "Failed to configure service: #{reason}"}
    end
  end

  defp check_service_status_with_retries(connection, app, retries) when retries > 0 do
    case get_app_service_status(connection, app) do
      {:ok, "active"} -> {:ok, "active"}
      {:ok, "activating"} -> 
        :timer.sleep(2000)
        check_service_status_with_retries(connection, app, retries - 1)
      {:ok, status} -> {:ok, status}
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp check_service_status_with_retries(connection, app, 0) do
    get_app_service_status(connection, app)
  end

  defp start_app_service(connection, app) do
    service_name = get_service_name(app)
    
    case SSHClient.execute_command(connection, "sudo systemctl start #{service_name}") do
      {:ok, {_, _, 0}} ->
        # Wait longer for Elixir application to start properly
        :timer.sleep(5000)
        
        # Check status multiple times as Elixir apps can take time to start
        case check_service_status_with_retries(connection, app, 3) do
          {:ok, "active"} -> {:ok, :started}
          {:ok, "activating"} -> 
            # Give it more time for activating state
            :timer.sleep(10000)
            case get_app_service_status(connection, app) do
              {:ok, "active"} -> {:ok, :started}
              {:ok, status} -> {:error, "Service is still #{status} after extended wait. Check logs with: journalctl -u #{service_name} -f"}
              {:error, reason} -> {:error, "Failed to check service status: #{reason}"}
            end
          {:ok, status} -> {:error, "Service started but status is: #{status}. Check logs with: journalctl -u #{service_name} -f"}
          {:error, reason} -> {:error, "Failed to check service status: #{reason}"}
        end
      
      {:ok, {_, error, exit_code}} ->
        {:error, "Failed to start service (exit #{exit_code}): #{error}"}
      
      {:error, reason} ->
        {:error, "Failed to start service: #{reason}"}
    end
  end

  defp cleanup_failed_installation(connection, extract_path, app) do
    service_name = get_service_name(app)
    
    # Stop and remove service if it exists
    SSHClient.execute_command(connection, "sudo systemctl stop #{service_name} 2>/dev/null || true")
    SSHClient.execute_command(connection, "sudo systemctl disable #{service_name} 2>/dev/null || true")
    SSHClient.execute_command(connection, "sudo rm -f /etc/systemd/system/#{service_name}.service")
    SSHClient.execute_command(connection, "sudo systemctl daemon-reload")
    
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

  defp generate_systemd_service(app, extract_path, connection) do
    service_name = get_service_name(app)
    start_command = get_start_command(extract_path, connection)
    
    # Get the username from SSH config (the user deploying the app)
    deploy_user = get_deploy_user(connection)
    
    # Generate a default SECRET_KEY_BASE if not provided
    secret_key_base = generate_secret_key_base()
    
    """
    [Unit]
    Description=ElixiHub App: #{app.name}
    After=network.target
    
    [Service]
    Type=exec
    User=#{deploy_user}
    Group=#{deploy_user}
    WorkingDirectory=#{extract_path}
    ExecStart=#{start_command}
    Restart=on-failure
    RestartSec=10
    TimeoutStartSec=60
    TimeoutStopSec=30
    Environment=PORT=#{get_app_port(app)}
    Environment=MIX_ENV=prod
    Environment=PHX_SERVER=true
    Environment=HOME=#{extract_path}
    Environment=RELEASE_COOKIE=elixihub-#{service_name}
    Environment=SECRET_KEY_BASE=#{secret_key_base}
    Environment=PHX_HOST=localhost
    #{get_app_specific_env_vars(app)}
    StandardOutput=journal
    StandardError=journal
    SyslogIdentifier=#{service_name}

    [Install]
    WantedBy=multi-user.target
    """
  end

  defp is_file?(connection, path) do
    case SSHClient.execute_command(connection, "test -f #{path}") do
      {:ok, {_, _, 0}} -> true
      _ -> false
    end
  end

  defp get_start_command(extract_path, connection) do
    # Try to detect the appropriate start command using remote filesystem
    IO.puts("Detecting start command for: #{extract_path}")
    
    # First, let's see what files are actually in the extract path
    case SSHClient.execute_command(connection, "find #{extract_path} -maxdepth 2 -type f -executable") do
      {:ok, {output, _, 0}} ->
        IO.puts("Executable files found:\n#{output}")
      _ ->
        IO.puts("Could not list executable files")
    end
    
    case SSHClient.execute_command(connection, "ls -la #{extract_path}/") do
      {:ok, {output, _, 0}} ->
        IO.puts("Root directory contents:\n#{output}")
      _ ->
        IO.puts("Could not list root directory")
    end
    
    cond do
      SSHClient.path_exists?(connection, Path.join(extract_path, "_build/prod/rel")) ->
        # Elixir release built with mix release - find the actual app name
        case SSHClient.execute_command(connection, "ls #{extract_path}/_build/prod/rel/") do
          {:ok, {output, _, 0}} ->
            app_dirs = output |> String.trim() |> String.split("\n") |> Enum.reject(&(&1 == ""))
            IO.puts("Found release directories: #{inspect(app_dirs)}")
            
            case app_dirs do
              [app_name | _] ->
                command = "#{extract_path}/_build/prod/rel/#{String.trim(app_name)}/bin/#{String.trim(app_name)} start"
                IO.puts("Detected Elixir release with _build: #{command}")
                command
              [] ->
                # Fallback to directory name
                release_name = extract_path |> Path.basename()
                command = "#{extract_path}/_build/prod/rel/#{release_name}/bin/#{release_name} start"
                IO.puts("Using directory name for release: #{command}")
                command
            end
          _ ->
            release_name = extract_path |> Path.basename()
            command = "#{extract_path}/_build/prod/rel/#{release_name}/bin/#{release_name} start"
            IO.puts("Could not list release dirs, using directory name: #{command}")
            command
        end
      
      SSHClient.path_exists?(connection, Path.join(extract_path, "bin")) ->
        # Elixir release in bin directory - find the actual executable
        IO.puts("Found bin directory, detecting executable...")
        
        # Find all executable files in bin directory, excluding .bat files
        case SSHClient.execute_command(connection, "find #{extract_path}/bin -type f -executable -not -name '*.bat'") do
          {:ok, {output, _, 0}} ->
            executables = output |> String.trim() |> String.split("\n") |> Enum.reject(&(&1 == "" or String.ends_with?(&1, ".bat")))
            IO.puts("Found non-.bat executables in bin: #{inspect(executables)}")
            
            case executables do
              [first_executable | _] ->
                command = "#{first_executable} start"
                IO.puts("Using first executable found: #{command}")
                command
              [] ->
                # Try to detect from directory listing
                case SSHClient.execute_command(connection, "ls -la #{extract_path}/bin/") do
                  {:ok, {listing, _, 0}} ->
                    IO.puts("Bin directory listing:\n#{listing}")
                    
                    # Extract executable names from listing (exclude .bat files)
                    potential_names = listing
                    |> String.split("\n")
                    |> Enum.filter(&(String.contains?(&1, "-rwxr-xr-x") and not String.ends_with?(&1, ".bat")))
                    |> Enum.map(&(String.split(&1) |> List.last()))
                    |> Enum.reject(&is_nil/1)
                    
                    IO.puts("Potential executable names from listing: #{inspect(potential_names)}")
                    
                    case potential_names do
                      [name | _] ->
                        command = "#{extract_path}/bin/#{name} start"
                        IO.puts("Using executable from listing: #{command}")
                        command
                      [] ->
                        # Last resort: try common patterns
                        release_name = extract_path |> Path.basename()
                        common_names = ["#{release_name}_app", "agent_app", "hello_world_app", release_name]
                        
                        found_executable = Enum.find(common_names, fn name ->
                          exe_path = Path.join(extract_path, "bin/#{name}")
                          IO.puts("Checking for common name: #{exe_path}")
                          SSHClient.path_exists?(connection, exe_path)
                        end)
                        
                        if found_executable do
                          command = "#{extract_path}/bin/#{found_executable} start"
                          IO.puts("Found executable by common name: #{command}")
                          command
                        else
                          # Final fallback
                          command = "#{extract_path}/bin/start"
                          IO.puts("Using final fallback: #{command}")
                          command
                        end
                    end
                  _ ->
                    command = "#{extract_path}/bin/start"
                    IO.puts("Could not list bin directory, using fallback: #{command}")
                    command
                end
            end
          _ ->
            command = "#{extract_path}/bin/start"
            IO.puts("Could not find executables, using fallback: #{command}")
            command
        end
      
      SSHClient.path_exists?(connection, Path.join(extract_path, "start.sh")) ->
        # Generic start script
        command = "#{extract_path}/start.sh"
        IO.puts("Detected start script: #{command}")
        command
      
      SSHClient.path_exists?(connection, Path.join(extract_path, "package.json")) ->
        # Node.js app
        command = "node #{extract_path}/index.js"
        IO.puts("Detected Node.js app: #{command}")
        command
      
      is_file?(connection, Path.join(extract_path, "app")) ->
        # Go binary (only if it's actually a file, not directory)
        command = "#{extract_path}/app"
        IO.puts("Detected Go binary: #{command}")
        command
      
      true ->
        # Default fallback
        command = "#{extract_path}/bin/start"
        IO.puts("Using default fallback: #{command}")
        command
    end
  end

  defp write_service_file_with_sudo(connection, content, path) do
    # Create a temporary file locally
    local_temp_file = Path.join(System.tmp_dir(), "service_#{:rand.uniform(10000)}")
    remote_temp_file = "/tmp/service_#{:rand.uniform(10000)}"
    
    IO.puts("Creating service file at: #{path}")
    IO.puts("Local temp file: #{local_temp_file}")
    IO.puts("Remote temp file: #{remote_temp_file}")
    IO.puts("Service content:\n#{content}")
    
    case File.write(local_temp_file, content) do
      :ok ->
        IO.puts("Successfully wrote local temp file")
        case SSHClient.upload_file(connection, local_temp_file, remote_temp_file) do
          {:ok, _} ->
            IO.puts("Successfully uploaded file to remote")
            # Use sudo to move the file to the system location and set proper ownership
            move_command = "sudo mv #{remote_temp_file} #{path}"
            IO.puts("Executing: #{move_command}")
            
            case SSHClient.execute_command(connection, move_command) do
              {:ok, {stdout, stderr, 0}} ->
                IO.puts("Successfully moved file to #{path}")
                IO.puts("Move stdout: #{stdout}")
                IO.puts("Move stderr: #{stderr}")
                File.rm(local_temp_file)
                
                # Set proper ownership and permissions for systemd service file
                chown_command = "sudo chown root:root #{path}"
                chmod_command = "sudo chmod 644 #{path}"
                
                case SSHClient.execute_command(connection, chown_command) do
                  {:ok, {_, _, 0}} ->
                    IO.puts("Successfully set ownership to root:root")
                    case SSHClient.execute_command(connection, chmod_command) do
                      {:ok, {_, _, 0}} ->
                        IO.puts("Successfully set permissions to 644")
                        
                        # Verify the file was created with correct ownership
                        case SSHClient.execute_command(connection, "ls -la #{path}") do
                          {:ok, {verify_output, _, 0}} ->
                            IO.puts("Service file verification: #{verify_output}")
                            {:ok, path}
                          {:ok, {_, verify_error, exit_code}} ->
                            IO.puts("Service file verification failed (exit #{exit_code}): #{verify_error}")
                            {:error, "Service file was moved but verification failed"}
                          {:error, verify_reason} ->
                            IO.puts("Service file verification error: #{verify_reason}")
                            {:error, "Service file verification error: #{verify_reason}"}
                        end
                      
                      {:ok, {_, chmod_error, exit_code}} ->
                        IO.puts("Failed to set permissions (exit #{exit_code}): #{chmod_error}")
                        {:error, "Failed to set service file permissions"}
                    end
                  
                  {:ok, {_, chown_error, exit_code}} ->
                    IO.puts("Failed to set ownership (exit #{exit_code}): #{chown_error}")
                    {:error, "Failed to set service file ownership"}
                end
              
              {:ok, {stdout, stderr, exit_code}} ->
                IO.puts("Move command failed (exit #{exit_code})")
                IO.puts("Move stdout: #{stdout}")
                IO.puts("Move stderr: #{stderr}")
                File.rm(local_temp_file)
                SSHClient.execute_command(connection, "rm -f #{remote_temp_file}")
                {:error, "Failed to move service file (exit #{exit_code}): #{stderr}"}
              
              {:error, reason} ->
                IO.puts("Move command error: #{inspect(reason)}")
                File.rm(local_temp_file)
                SSHClient.execute_command(connection, "rm -f #{remote_temp_file}")
                {:error, "Move command failed: #{inspect(reason)}"}
            end
          
          {:error, reason} ->
            IO.puts("File upload failed: #{inspect(reason)}")
            File.rm(local_temp_file)
            {:error, "File upload failed: #{inspect(reason)}"}
        end
      
      {:error, reason} ->
        IO.puts("Failed to write local temp file: #{inspect(reason)}")
        {:error, "Failed to write temp service file: #{inspect(reason)}"}
    end
  end

  defp get_deploy_user(connection) do
    case SSHClient.execute_command(connection, "whoami") do
      {:ok, {username, _, 0}} ->
        String.trim(username)
      
      _ ->
        "ubuntu"  # fallback
    end
  end

  defp get_app_port(app) do
    # Try to determine the port from app configuration or use a default
    cond do
      app.url && String.contains?(app.url, ":") ->
        # Extract port from URL if present
        case Regex.run(~r/:(\d+)/, app.url) do
          [_, port] -> port
          _ -> get_default_port_by_name(app.name)
        end
      
      true ->
        get_default_port_by_name(app.name)
    end
  end
  
  defp get_default_port_by_name(app_name) do
    # Set default ports based on app name
    cond do
      String.contains?(String.downcase(app_name), "agent") -> "4003"
      String.contains?(String.downcase(app_name), "hello") -> "4001"
      true -> "4000"  # fallback default
    end
  end
  
  defp generate_secret_key_base do
    # Generate a 64-byte random secret key base
    :crypto.strong_rand_bytes(64) |> Base.encode64()
  end
  
  defp get_app_specific_env_vars(app) do
    app_name_lower = String.downcase(app.name)
    
    cond do
      String.contains?(app_name_lower, "agent") ->
        ~s"""
        Environment=OPENAI_API_KEY=your_openai_api_key_here
        Environment=ELIXIHUB_JWT_SECRET=your_elixihub_jwt_secret_here
        Environment=ELIXIHUB_URL=http://localhost:4005
        Environment=HELLO_WORLD_MCP_URL=http://localhost:4001/api/mcp
        """
      
      String.contains?(app_name_lower, "hello") ->
        ~s"""
        Environment=ELIXIHUB_JWT_SECRET=your_elixihub_jwt_secret_here
        Environment=ELIXIHUB_URL=http://localhost:4005
        """
      
      true ->
        "# No app-specific environment variables"
    end
  end

  # Undeployment helper functions

  defp execute_undeployment_steps([], results) do
    {:ok, %{
      steps_completed: Enum.reverse(results),
      status: :completely_undeployed,
      message: "Application successfully undeployed"
    }}
  end

  defp execute_undeployment_steps([{step_name, step_fn} | remaining_steps], results) do
    IO.puts("Executing undeployment step: #{step_name}")
    
    case step_fn.() do
      {:ok, result} ->
        IO.puts("Step '#{step_name}' succeeded: #{inspect(result)}")
        step_result = %{step: step_name, status: :success, result: result}
        execute_undeployment_steps(remaining_steps, [step_result | results])
      
      {:error, reason} ->
        IO.puts("Step '#{step_name}' failed: #{inspect(reason)}")
        step_result = %{step: step_name, status: :failed, error: reason}
        # Continue with remaining steps even if one fails, but log the failure
        execute_undeployment_steps(remaining_steps, [step_result | results])
    end
  end

  defp disable_app_service(connection, service_name) do
    case SSHClient.execute_command(connection, "sudo systemctl disable #{service_name}") do
      {:ok, {_, _, 0}} ->
        {:ok, :disabled}
      
      {:ok, {_, error, exit_code}} ->
        # Don't fail if service doesn't exist or is already disabled
        if String.contains?(error, "No such file") or String.contains?(error, "not found") do
          {:ok, :already_disabled}
        else
          {:error, "Failed to disable service (exit #{exit_code}): #{error}"}
        end
      
      {:error, reason} ->
        {:error, "Failed to disable service: #{reason}"}
    end
  end

  defp remove_service_file(connection, service_path) do
    case SSHClient.execute_command(connection, "sudo rm -f #{service_path}") do
      {:ok, {_, _, 0}} ->
        {:ok, :removed}
      
      {:ok, {_, error, exit_code}} ->
        {:error, "Failed to remove service file (exit #{exit_code}): #{error}"}
      
      {:error, reason} ->
        {:error, "Failed to remove service file: #{reason}"}
    end
  end

  defp reload_systemd(connection) do
    case SSHClient.execute_command(connection, "sudo systemctl daemon-reload") do
      {:ok, {_, _, 0}} ->
        {:ok, :reloaded}
      
      {:ok, {_, error, exit_code}} ->
        {:error, "Failed to reload systemd (exit #{exit_code}): #{error}"}
      
      {:error, reason} ->
        {:error, "Failed to reload systemd: #{reason}"}
    end
  end

  defp remove_app_files(connection, extract_path) do
    case SSHClient.execute_command(connection, "rm -rf #{extract_path}") do
      {:ok, {_, _, 0}} ->
        {:ok, :removed}
      
      {:ok, {_, error, exit_code}} ->
        # Don't fail if directory doesn't exist
        if String.contains?(error, "No such file or directory") do
          {:ok, :already_removed}
        else
          {:error, "Failed to remove app files (exit #{exit_code}): #{error}"}
        end
      
      {:error, reason} ->
        {:error, "Failed to remove app files: #{reason}"}
    end
  end
end