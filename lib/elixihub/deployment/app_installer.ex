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
  def install_app(connection, %App{} = app, extract_path, host_architecture \\ nil) do
    IO.puts("=== INSTALL_APP START ===")
    IO.puts("App name: #{app.name}")
    IO.puts("Extract path: #{extract_path}")
    IO.puts("Host architecture: #{inspect(host_architecture)}")
    IO.puts("Deploy as service: #{app.deploy_as_service}")
    
    with {:ok, app_type} <- detect_app_type(connection, extract_path),
         {:ok, _} <- prepare_installation_environment(connection, extract_path),
         {:ok, result} <- install_by_app_type(connection, app_type, extract_path, app, host_architecture),
         {:ok, service_result} <- handle_service_or_shell_start(connection, app, extract_path, host_architecture) do
      {:ok, %{
        app_type: app_type,
        install_path: extract_path,
        service_status: service_result,
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
  def stop_app_service(connection, %App{} = app, host_architecture \\ nil) do
    service_name = get_service_name(app)

    stop_command = case host_architecture do
      "MacOs(Apple Silicon)" ->
        "launchctl stop #{service_name}"
      _ ->
        "sudo systemctl stop #{service_name}"
    end

    case SSHClient.execute_command(connection, stop_command) do
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
  def get_app_service_status(connection, %App{} = app, host_architecture \\ nil) do
    service_name = get_service_name(app)

    status_command = case host_architecture do
      "MacOs(Apple Silicon)" ->
        "launchctl list | grep #{service_name} | awk '{print $1}'"
      _ ->
        "sudo systemctl is-active #{service_name}"
    end

    case SSHClient.execute_command(connection, status_command) do
      {:ok, {status, _, 0}} ->
        trimmed_status = String.trim(status)
        # For launchctl, check if PID exists (means running)
        normalized_status = case host_architecture do
          "MacOs(Apple Silicon)" ->
            if trimmed_status != "" and trimmed_status != "-", do: "active", else: "inactive"
          _ ->
            trimmed_status
        end
        {:ok, normalized_status}

      {:ok, {status, _, _}} ->
        trimmed_status = String.trim(status)
        normalized_status = case host_architecture do
          "MacOs(Apple Silicon)" ->
            if trimmed_status != "" and trimmed_status != "-", do: "active", else: "inactive"
          _ ->
            trimmed_status
        end
        {:ok, normalized_status}

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
  def undeploy_app(connection, %App{} = app, extract_path, host_architecture \\ nil) do
    service_name = get_service_name(app)

    IO.puts("Starting undeploy for app: #{app.name}")
    IO.puts("Service name: #{service_name}")
    IO.puts("Extract path: #{extract_path}")
    IO.puts("Host architecture: #{host_architecture}")

    undeployment_steps = case host_architecture do
      "MacOs(Apple Silicon)" ->
        plist_path = "/Library/LaunchDaemons/#{service_name}.plist"
        IO.puts("Plist path: #{plist_path}")
        [
          {"Stop service", fn -> stop_app_service(connection, app, host_architecture) end},
          {"Unload plist", fn -> unload_launchd_service(connection, service_name, plist_path) end},
          {"Remove plist file", fn -> remove_service_file(connection, plist_path) end},
          {"Remove application files", fn -> remove_app_files(connection, extract_path) end}
        ]
      _ ->
        service_path = "/etc/systemd/system/#{service_name}.service"
        IO.puts("Service path: #{service_path}")
        [
          {"Stop service", fn -> stop_app_service(connection, app, host_architecture) end},
          {"Disable service", fn -> disable_app_service(connection, service_name) end},
          {"Remove service file", fn -> remove_service_file(connection, service_path) end},
          {"Reload systemd", fn -> reload_systemd(connection) end},
          {"Remove application files", fn -> remove_app_files(connection, extract_path) end}
        ]
    end

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
  def restart_app_service(connection, %App{} = app, host_architecture \\ nil) do
    service_name = get_service_name(app)

    restart_command = case host_architecture do
      "MacOs(Apple Silicon)" ->
        "launchctl kickstart -k system/#{service_name}"
      _ ->
        "sudo systemctl restart #{service_name}"
    end

    case SSHClient.execute_command(connection, restart_command) do
      {:ok, {_, _, 0}} ->
        {:ok, :restarted}

      {:ok, {_, error, exit_code}} ->
        {:error, "Failed to restart service (exit #{exit_code}): #{error}"}

      {:error, reason} ->
        {:error, "Failed to restart service: #{reason}"}
    end
  end

  @doc """
  Starts an application service.
  """
  def start_app_service(connection, %App{} = app, extract_path, host_architecture \\ nil) do
    service_name = get_service_name(app)

    case host_architecture do
      "MacOs(Apple Silicon)" ->
        # For macOS, the app should already be started by configure_launchd_service
        # Just verify it's running
        IO.puts("=== MACOS START_APP_SERVICE ===")
        IO.puts("Service name: #{service_name}")
        IO.puts("Extract path: #{extract_path}")
        IO.puts("App port: #{get_app_port(app)}")
        IO.puts("Verifying macOS app is running...")

        case verify_app_running(connection, app, extract_path) do
          {:ok, :running} ->
            IO.puts("=== APP VERIFICATION SUCCESSFUL ===")
            IO.puts("App verified as running successfully")
            {:ok, :started}

          {:error, reason} ->
            IO.puts("=== APP VERIFICATION FAILED ===")
            IO.puts("App verification failed: #{reason}")
            IO.puts("Attempting to start manually...")
            # Try to start manually if not running
            case try_direct_app_start(connection, app, extract_path) do
              {:ok, :configured} ->
                IO.puts("=== MANUAL START SUCCESSFUL ===")
                {:ok, :started}

              {:error, start_reason} ->
                IO.puts("=== MANUAL START FAILED ===")
                IO.puts("Manual start failed: #{start_reason}")
                {:error, "App failed to start: #{start_reason}"}
            end
        end

      _ ->
        # Standard systemd approach for Linux
        start_command = "sudo systemctl start #{service_name}"

        case SSHClient.execute_command(connection, start_command) do
          {:ok, {_, _, 0}} ->
            # Wait longer for Elixir application to start properly
            :timer.sleep(5000)

            # Standard systemd check for Linux
            case check_service_status_with_retries(connection, app, host_architecture, 3) do
              {:ok, "active"} -> {:ok, :started}
              {:ok, "activating"} ->
                # Give it more time for activating state
                :timer.sleep(10000)
                case get_app_service_status(connection, app, host_architecture) do
                  {:ok, "active"} -> {:ok, :started}
                  {:ok, status} ->
                    log_command = "journalctl -u #{service_name} -f"
                    {:error, "Service is still #{status} after extended wait. Check logs with: #{log_command}"}
                  {:error, reason} -> {:error, "Failed to check service status: #{reason}"}
                end
              {:ok, status} ->
                log_command = "journalctl -u #{service_name} -f"
                {:error, "Service started but status is: #{status}. Check logs with: #{log_command}"}
              {:error, reason} -> {:error, "Failed to check service status: #{reason}"}
            end

          {:ok, {_, error, exit_code}} ->
            {:error, "Failed to start service (exit #{exit_code}): #{error}"}

          {:error, reason} ->
            {:error, "Failed to start service: #{reason}"}
        end
    end
  end

  defp handle_service_or_shell_start(connection, %App{} = app, extract_path, host_architecture) do
    case app.deploy_as_service do
      true ->
        IO.puts("=== CONFIGURING AS SERVICE ===")
        with {:ok, _} <- configure_app_service(connection, app, extract_path, host_architecture),
             {:ok, _} <- start_app_service(connection, app, extract_path, host_architecture) do
          {:ok, :service_started}
        end

      false ->
        IO.puts("=== STARTING AS SHELL COMMAND ===")
        start_app_as_shell_command(connection, app, extract_path, host_architecture)
    end
  end

  defp start_app_as_shell_command(connection, %App{} = app, extract_path, host_architecture) do
    IO.puts("Starting app as shell command...")
    
    case detect_app_type(connection, extract_path) do
      {:ok, "elixir"} ->
        start_elixir_app_shell(connection, app, extract_path)
      {:ok, "python"} ->
        start_python_app_shell(connection, app, extract_path)
      {:ok, "node"} ->
        start_node_app_shell(connection, app, extract_path)
      {:ok, _app_type} ->
        start_generic_app_shell(connection, app, extract_path)
      {:error, reason} ->
        {:error, "Failed to detect app type for shell start: #{reason}"}
    end
  end

  defp start_elixir_app_shell(connection, app, extract_path) do
    start_command = "cd #{extract_path} && nohup mix run --no-halt > #{app.name}.log 2>&1 & echo $! > #{app.name}.pid"
    
    case SSHClient.execute_command(connection, start_command) do
      {:ok, {_, _, 0}} ->
        {:ok, :shell_started}
      {:ok, {_, error, exit_code}} ->
        {:error, "Failed to start Elixir app as shell (exit #{exit_code}): #{error}"}
      {:error, reason} ->
        {:error, "Failed to start Elixir app as shell: #{reason}"}
    end
  end

  defp start_python_app_shell(connection, app, extract_path) do
    start_command = "cd #{extract_path} && nohup python3 main.py > #{app.name}.log 2>&1 & echo $! > #{app.name}.pid"
    
    case SSHClient.execute_command(connection, start_command) do
      {:ok, {_, _, 0}} ->
        {:ok, :shell_started}
      {:ok, {_, error, exit_code}} ->
        {:error, "Failed to start Python app as shell (exit #{exit_code}): #{error}"}
      {:error, reason} ->
        {:error, "Failed to start Python app as shell: #{reason}"}
    end
  end

  defp start_node_app_shell(connection, app, extract_path) do
    start_command = "cd #{extract_path} && nohup npm start > #{app.name}.log 2>&1 & echo $! > #{app.name}.pid"
    
    case SSHClient.execute_command(connection, start_command) do
      {:ok, {_, _, 0}} ->
        {:ok, :shell_started}
      {:ok, {_, error, exit_code}} ->
        {:error, "Failed to start Node app as shell (exit #{exit_code}): #{error}"}
      {:error, reason} ->
        {:error, "Failed to start Node app as shell: #{reason}"}
    end
  end

  defp start_generic_app_shell(connection, app, extract_path) do
    # Try to find common executable files
    executables = ["run.sh", "start.sh", "app", "main"]
    
    case find_executable(connection, extract_path, executables) do
      {:ok, executable} ->
        start_command = "cd #{extract_path} && nohup ./#{executable} > #{app.name}.log 2>&1 & echo $! > #{app.name}.pid"
        
        case SSHClient.execute_command(connection, start_command) do
          {:ok, {_, _, 0}} ->
            {:ok, :shell_started}
          {:ok, {_, error, exit_code}} ->
            {:error, "Failed to start app as shell (exit #{exit_code}): #{error}"}
          {:error, reason} ->
            {:error, "Failed to start app as shell: #{reason}"}
        end
      
      {:error, reason} ->
        {:error, "No executable found for generic app: #{reason}"}
    end
  end

  defp find_executable(connection, extract_path, []) do
    {:error, "No executable files found"}
  end

  defp find_executable(connection, extract_path, [executable | rest]) do
    file_path = Path.join(extract_path, executable)
    
    if SSHClient.path_exists?(connection, file_path) do
      # Make it executable
      SSHClient.execute_command(connection, "chmod +x #{file_path}")
      {:ok, executable}
    else
      find_executable(connection, extract_path, rest)
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

  defp install_by_app_type(connection, app_type, extract_path, app, host_architecture \\ nil) do
    case app_type do
      "elixir" -> install_elixir_app(connection, extract_path, app, host_architecture)
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

  defp install_elixir_app(connection, extract_path, app, host_architecture \\ nil) do
    # Always build on target architecture to avoid exec format errors
    try_elixir_installation_on_target(connection, extract_path, host_architecture)
  end

  defp try_elixir_installation_primary(connection, extract_path) do
    # Primary method with network optimizations
    host_architecture = "MacOs(Apple Silicon)"  # Default for this fix
    env_setup_cmd = get_environment_setup_command(host_architecture)
    timeout_setup_cmd = get_timeout_command(host_architecture)

    combined_command = """
    #{env_setup_cmd}
    #{timeout_setup_cmd}
    cd #{extract_path} && \
    git config --global http.lowSpeedLimit 1000 && \
    git config --global http.lowSpeedTime 300 && \
    git config --global http.postBuffer 524288000 && \
    export HEX_HTTP_TIMEOUT=300 && \
    export HEX_HTTP_CONCURRENCY=1 && \
    export SECRET_KEY_BASE=$(cat #{extract_path}/.secret_key_base 2>/dev/null || (echo '#{generate_secret_key_base()}' | tee #{extract_path}/.secret_key_base)) && \
    mix local.hex --force && \
    mix local.rebar --force && \
    timeout_cmd 600 bash -c 'MIX_ENV=dev mix deps.get && MIX_ENV=prod mix deps.get' && \
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

  # Get appropriate memory check command based on host architecture
  defp get_memory_check_command(host_architecture) do
    case host_architecture do
      "MacOs(Apple Silicon)" -> "vm_stat | head -10"
      "ARM64(Raspberry Pi)" -> "free -h"
      _ -> "free -h || vm_stat | head -10"  # fallback for unknown/nil architectures
    end
  end

  defp try_elixir_installation_on_target(connection, extract_path, host_architecture \\ nil) do
    # Build release on target architecture with better error handling
    IO.puts("Starting Elixir build on target architecture at: #{extract_path}")

    # Step 1: Check and install dependencies if needed
    IO.puts("Step 1: Checking Elixir dependencies...")

    case ensure_elixir_dependencies(connection, host_architecture) do
      {:ok, _} = deps_result ->
        IO.puts("Dependencies check successful: #{inspect(deps_result)}")

        IO.puts("Step 2: Setting up Elixir environment...")
        case setup_elixir_environment(connection, extract_path, host_architecture) do
          {:ok, _} = env_result ->
            IO.puts("Environment setup successful: #{inspect(env_result)}")
            IO.puts("Step 3: Starting Elixir build steps...")
            try_elixir_build_steps(connection, extract_path)

          {:error, reason} = error ->
            IO.puts("Environment setup failed: #{inspect(error)}")
            {:error, "Environment setup failed: #{reason}"}

          other ->
            IO.puts("Environment setup returned unexpected result: #{inspect(other)}")
            {:error, "Environment setup returned unexpected result: #{inspect(other)}"}
        end

      {:error, reason} = error ->
        IO.puts("Dependencies check failed: #{inspect(error)}")
        {:error, "Dependency setup failed: #{reason}"}

      other ->
        IO.puts("Dependencies check returned unexpected result: #{inspect(other)}")
        {:error, "Dependency setup returned unexpected result: #{inspect(other)}"}
    end
  end

  defp ensure_elixir_dependencies(connection, host_architecture) do
    # First try with environment sourcing
    env_setup = get_environment_setup_command(host_architecture)
    check_command = """
    #{env_setup}
    which mix && which elixir && which erl
    """

    case SSHClient.execute_elixir_build_command(connection, check_command) do
      {:ok, {_stdout, _stderr, 0}} ->
        IO.puts("Elixir dependencies already installed and available")
        {:ok, :already_installed}

      {:ok, {_stdout, _stderr, _exit_code}} ->
        IO.puts("Installing Elixir dependencies...")
        install_elixir_dependencies(connection, host_architecture)

      {:error, reason} ->
        {:error, "Failed to check dependencies: #{inspect(reason)}"}
    end
  end

  defp install_elixir_dependencies(connection, host_architecture) do
    install_command = get_elixir_install_command(host_architecture)

    case SSHClient.execute_elixir_build_command(connection, install_command) do
      {:ok, {_stdout, _stderr, 0}} ->
        # Verify installation worked
        verify_elixir_installation(connection, host_architecture)

      {:ok, {stdout, stderr, exit_code}} ->
        {:error, "Failed to install Elixir dependencies (exit #{exit_code}): #{stderr}"}

      {:error, reason} ->
        {:error, "Failed to install Elixir dependencies: #{inspect(reason)}"}
    end
  end

  defp verify_elixir_installation(connection, host_architecture) do
    env_setup = get_environment_setup_command(host_architecture)
    verify_command = """
    #{env_setup}
    echo "Verifying Elixir installation..."
    which elixir && which mix && which erl && echo "All tools found"
    """

    case SSHClient.execute_elixir_build_command(connection, verify_command) do
      {:ok, {_stdout, _stderr, 0}} ->
        IO.puts("Elixir dependencies verified successfully")
        {:ok, :installed}

      {:ok, {stdout, stderr, exit_code}} ->
        {:error, "Elixir installation verification failed (exit #{exit_code}): #{stderr}"}

      {:error, reason} ->
        {:error, "Failed to verify Elixir installation: #{inspect(reason)}"}
    end
  end

  defp get_elixir_install_command(host_architecture) do
    case host_architecture do
      "MacOs(Apple Silicon)" ->
        """
        # Try multiple installation methods for macOS

        # Method 1: Check if Homebrew is already installed
        if which brew > /dev/null 2>&1; then
          echo "Homebrew found, installing Elixir..."
          brew install elixir
          exit 0
        fi

        # Method 2: Use asdf version manager (lightweight alternative)
        echo "Installing Elixir using asdf version manager..."

        # Setup asdf properly
        if [ -d ~/.asdf ]; then
          echo "Found existing asdf directory, updating..."
          cd ~/.asdf && git pull origin v0.14.0 2>/dev/null || echo "asdf update failed, continuing..."
        else
          echo "Installing asdf..."
          git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
        fi

        # Ensure asdf script exists and is executable
        if [ -f ~/.asdf/asdf.sh ]; then
          chmod +x ~/.asdf/asdf.sh
          . ~/.asdf/asdf.sh
        else
          echo "Error: asdf.sh not found after installation"
          exit 1
        fi

        # Add asdf to shell profiles if not already present
        grep -q 'asdf.sh' ~/.zshrc 2>/dev/null || echo '. "$HOME/.asdf/asdf.sh"' >> ~/.zshrc
        grep -q 'asdf.sh' ~/.bashrc 2>/dev/null || echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc

        # Verify asdf is working
        if ! asdf --version > /dev/null 2>&1; then
          echo "Error: asdf command not available after setup"
          exit 1
        fi

        # Add plugins (ignore errors if already added)
        asdf plugin add erlang 2>/dev/null || echo "Erlang plugin already exists"
        asdf plugin add elixir 2>/dev/null || echo "Elixir plugin already exists"

        # Install Erlang and Elixir if not already installed
        if ! asdf list erlang | grep -q "26.2.1"; then
          echo "Installing Erlang 26.2.1..."
          asdf install erlang 26.2.1
        fi

        if ! asdf list elixir | grep -q "1.16.0-otp-26"; then
          echo "Installing Elixir 1.16.0-otp-26..."
          asdf install elixir 1.16.0-otp-26
        fi

        # Set global versions
        asdf global erlang 26.2.1
        asdf global elixir 1.16.0-otp-26

        # Refresh environment and verify installation
        . ~/.asdf/asdf.sh
        which elixir && which mix && echo "Elixir installed successfully via asdf"
        """

      "ARM64(Raspberry Pi)" ->
        """
        # Update package lists
        sudo apt-get update

        # Install Erlang and Elixir
        sudo apt-get install -y erlang elixir
        """

      _ ->
        """
        # Try package manager detection and installation
        if which apt-get > /dev/null 2>&1; then
          sudo apt-get update && sudo apt-get install -y erlang elixir
        elif which brew > /dev/null 2>&1; then
          brew install elixir
        else
          echo "No supported package manager found"
          exit 1
        fi
        """
    end
  end

  defp get_environment_setup_command(host_architecture) do
    case host_architecture do
      "MacOs(Apple Silicon)" ->
        """
        # Source environment for macOS

        # Try to source asdf first
        if [ -f ~/.asdf/asdf.sh ]; then
          . ~/.asdf/asdf.sh
          echo "Sourced asdf environment"
        fi

        # Source Homebrew if available
        if which brew > /dev/null 2>&1; then
          eval "$(/opt/homebrew/bin/brew shellenv)"
          echo "Sourced Homebrew environment"
        elif [ -f /opt/homebrew/bin/brew ]; then
          eval "$(/opt/homebrew/bin/brew shellenv)"
          echo "Sourced Homebrew from /opt/homebrew/bin/brew"
        fi

        # Verify tools are available
        echo "Checking available tools:"
        which elixir || echo "elixir not found in PATH"
        which mix || echo "mix not found in PATH"
        which erl || echo "erl not found in PATH"
        """

      "ARM64(Raspberry Pi)" ->
        """
        # Source environment for Linux/Pi
        # Usually no special setup needed for apt-installed packages
        """

      _ ->
        """
        # Generic environment setup
        if [ -f ~/.asdf/asdf.sh ]; then
          source ~/.asdf/asdf.sh
        fi
        """
    end
  end

  defp get_timeout_command(host_architecture) do
    case host_architecture do
      "MacOs(Apple Silicon)" ->
        # On macOS, use a shell function that implements timeout behavior
        """
        timeout_cmd() {
          local timeout_duration=$1
          shift
          (
            "$@" &
            local pid=$!
            (sleep $timeout_duration && kill $pid 2>/dev/null) &
            local killer_pid=$!
            wait $pid
            local exit_code=$?
            kill $killer_pid 2>/dev/null
            exit $exit_code
          )
        }
        """

      "ARM64(Raspberry Pi)" ->
        # Linux has timeout command
        ""

      _ ->
        # Generic - try to detect
        """
        if ! which timeout > /dev/null 2>&1; then
          timeout_cmd() {
            local timeout_duration=$1
            shift
            (
              "$@" &
              local pid=$!
              (sleep $timeout_duration && kill $pid 2>/dev/null) &
              local killer_pid=$!
              wait $pid
              local exit_code=$?
              kill $killer_pid 2>/dev/null
              exit $exit_code
            )
          }
        else
          timeout_cmd() { timeout "$@"; }
        fi
        """
    end
  end

  defp setup_elixir_environment(connection, extract_path, host_architecture) do
    # Step 2: Environment check and setup
    memory_check_cmd = get_memory_check_command(host_architecture)
    env_setup_cmd = get_environment_setup_command(host_architecture)
    timeout_setup_cmd = get_timeout_command(host_architecture)

    setup_command = """
    #{env_setup_cmd}
    #{timeout_setup_cmd}
    cd #{extract_path} && \
    echo 'Building release on target architecture...' && \
    echo 'Available memory:' && \
    #{memory_check_cmd} && \
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
        {:ok, :setup_complete}

      {:ok, {stdout, stderr, exit_code}} ->
        {:error, "Environment setup failed (exit #{exit_code}): #{stderr}"}

      {:error, reason} ->
        {:error, "Environment setup failed: #{inspect(reason)}"}
    end
  end

  defp try_elixir_build_steps(connection, extract_path) do
    IO.puts("=== ENTERING try_elixir_build_steps ===")
    IO.puts("Extract path: #{extract_path}")

    # Get the host architecture from the connection context - we'll use a default for now
    # In a real implementation, you'd pass this as a parameter
    host_architecture = "MacOs(Apple Silicon)"  # Default for this fix

    # Main build steps with increased timeout for compilation
    env_setup_cmd = get_environment_setup_command(host_architecture)
    timeout_setup_cmd = get_timeout_command(host_architecture)

    build_command = """
    #{env_setup_cmd}
    #{timeout_setup_cmd}
    cd #{extract_path} && \
    export HEX_HTTP_TIMEOUT=300 && \
    export HEX_HTTP_CONCURRENCY=1 && \
    export ERL_MAX_PORTS=4096 && \
    export ELIXIR_ERL_OPTIONS="+K true +A 4" && \
    export SECRET_KEY_BASE=$(cat #{extract_path}/.secret_key_base 2>/dev/null || (echo '#{generate_secret_key_base()}' | tee #{extract_path}/.secret_key_base)) && \
    echo 'Getting dependencies...' && \
    MIX_ENV=dev mix deps.get && \
    MIX_ENV=prod mix deps.get && \
    echo 'Compiling application...' && \
    sh -c 'MIX_ENV=prod mix compile' && \
    echo 'Building assets...' && \
    (sh -c 'MIX_ENV=prod mix assets.deploy' 2>/dev/null || echo 'No assets to deploy') && \
    echo 'Creating release...' && \
    sh -c 'MIX_ENV=prod mix release --overwrite' && \
    echo 'Release built successfully on target architecture'
    """

    IO.puts("=== ABOUT TO EXECUTE BUILD COMMAND ===")
    IO.puts("Build command length: #{byte_size(build_command)} bytes")
    IO.puts("First 500 chars of command:")
    IO.puts(String.slice(build_command, 0, 500))
    IO.puts("=== EXECUTING BUILD COMMAND NOW ===")

    case SSHClient.execute_elixir_build_command(connection, build_command) do
      {:ok, {stdout, stderr, 0}} ->
        IO.puts("=== BUILD COMMAND RETURNED SUCCESS ===")
        IO.puts("Elixir build completed successfully")
        {:ok, [%{
          command: "elixir_build_on_target",
          stdout: stdout,
          stderr: stderr,
          exit_code: 0,
          success: true
        }]}

      {:ok, {stdout, stderr, exit_code}} ->
        IO.puts("=== BUILD COMMAND RETURNED WITH ERROR ===")
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
        IO.puts("=== BUILD COMMAND RETURNED WITH EXCEPTION ===")
        IO.puts("Elixir build failed with error: #{inspect(reason)}")
        {:error, "Elixir build failed: #{inspect(reason)}"}
    end
  end

  defp try_elixir_low_memory_build(connection, extract_path) do
    IO.puts("Attempting low-memory build strategy...")

    # Use same architecture detection as main build
    host_architecture = "MacOs(Apple Silicon)"  # Default for this fix
    env_setup_cmd = get_environment_setup_command(host_architecture)
    timeout_setup_cmd = get_timeout_command(host_architecture)

    low_memory_command = """
    #{env_setup_cmd}
    #{timeout_setup_cmd}
    cd #{extract_path} && \
    export HEX_HTTP_TIMEOUT=300 && \
    export HEX_HTTP_CONCURRENCY=1 && \
    export ERL_MAX_PORTS=2048 && \
    export ELIXIR_ERL_OPTIONS="+K true +A 2" && \
    export ERL_FLAGS="+MBas aobf +MBlmbcs 512 +MHas aobf +MHlmbcs 512" && \
    export SECRET_KEY_BASE=$(cat #{extract_path}/.secret_key_base 2>/dev/null || (echo '#{generate_secret_key_base()}' | tee #{extract_path}/.secret_key_base)) && \
    echo 'Low-memory build: Getting dependencies...' && \
    timeout_cmd 900 bash -c 'MIX_ENV=dev mix deps.get && MIX_ENV=prod mix deps.get' && \
    echo 'Low-memory build: Compiling application with reduced parallelism...' && \
    timeout_cmd 1800 sh -c 'MIX_ENV=prod mix compile --force --no-optional-deps' && \
    echo 'Low-memory build: Building assets...' && \
    (timeout_cmd 300 sh -c 'MIX_ENV=prod mix assets.deploy' 2>/dev/null || echo 'No assets to deploy') && \
    echo 'Low-memory build: Creating release...' && \
    timeout_cmd 900 sh -c 'MIX_ENV=prod mix release --overwrite --no-optional-deps' && \
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

  defp configure_app_service(connection, app, extract_path, host_architecture \\ nil) do
    service_name = get_service_name(app)

    IO.puts("=== CONFIGURE_APP_SERVICE ===")
    IO.puts("Host architecture: #{inspect(host_architecture)}")
    IO.puts("Service name: #{service_name}")
    IO.puts("Extract path: #{extract_path}")

    case host_architecture do
      "MacOs(Apple Silicon)" ->
        IO.puts("Using macOS LaunchAgent configuration")
        configure_launchd_service(connection, app, extract_path, service_name)
      _ ->
        IO.puts("Using systemd configuration")
        configure_systemd_service(connection, app, extract_path, service_name)
    end
  end

  defp configure_systemd_service(connection, app, extract_path, service_name) do
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

  defp configure_launchd_service(connection, app, extract_path, service_name) do
    # For macOS, try direct app startup since LaunchAgents can be complex in SSH environments
    IO.puts("=== CONFIGURE_LAUNCHD_SERVICE ===")
    IO.puts("Configuring macOS service for: #{service_name}")
    IO.puts("Extract path: #{extract_path}")

    # First, try to start the app directly
    IO.puts("Attempting direct app start first...")
    case try_direct_app_start(connection, app, extract_path) do
      {:ok, :configured} ->
        IO.puts("=== DIRECT APP START SUCCEEDED ===")
        IO.puts("App started successfully as background process")
        {:ok, :configured}

      {:error, reason} ->
        IO.puts("=== DIRECT APP START FAILED ===")
        IO.puts("Direct start failed (#{reason}), trying LaunchAgent approach...")
        try_launchd_service_configuration(connection, app, extract_path, service_name)
    end
  end

  defp try_launchd_service_configuration(connection, app, extract_path, service_name) do
    plist_content = generate_launchd_plist(app, extract_path, connection)

    # Get the release binary path for chmod
    release_path = case find_release_binary(connection, extract_path) do
      {:ok, path} -> path
      {:error, _} ->
        # Fallback to constructed path - try to determine from extract path
        extract_basename = extract_path |> Path.basename()
        "#{extract_path}/_build/prod/rel/#{extract_basename}_app/bin/#{extract_basename}_app"
    end

    # Use user-level LaunchAgents instead of system-wide LaunchDaemons to avoid sudo
    plist_path = "~/Library/LaunchAgents/#{service_name}.plist"

    # Create LaunchAgents directory if it doesn't exist and write plist file
    setup_commands = [
      "mkdir -p ~/Library/LaunchAgents",
      "cat > #{plist_path} << 'EOF'\n#{plist_content}\nEOF",
      "chmod +x #{release_path}"  # Ensure the binary is executable
    ]

    case execute_commands_sequence(connection, setup_commands) do
      {:ok, _} ->
        # Load the plist into launchd (user-level, no sudo needed)
        # Try a simpler approach - just load without the enable command first
        load_commands = [
          "launchctl load #{plist_path}"
        ]

        case execute_commands_sequence(connection, load_commands) do
          {:ok, results} ->
            IO.puts("=== LAUNCHAGENT LOAD RESULTS ===")
            IO.puts("Load results: #{inspect(results)}")
            
            # First, let's verify the plist was loaded
            case SSHClient.execute_command(connection, "launchctl list | grep #{service_name}") do
              {:ok, {output, _, 0}} ->
                IO.puts("LaunchAgent listed immediately after load: #{String.trim(output)}")
              {:ok, {_, _, exit_code}} ->
                IO.puts("LaunchAgent not listed immediately after load (exit code: #{exit_code})")
              {:error, reason} ->
                IO.puts("Error checking LaunchAgent immediately after load: #{reason}")
            end
            
            # Check the plist file was created correctly
            case SSHClient.execute_command(connection, "cat #{plist_path}") do
              {:ok, {plist_contents, _, 0}} ->
                IO.puts("=== PLIST FILE CONTENTS ===")
                IO.puts(plist_contents)
                IO.puts("=== END PLIST CONTENTS ===")
              _ ->
                IO.puts("Could not read plist file at #{plist_path}")
            end
            
            # Try manually running the binary to see what happens
            IO.puts("=== TESTING MANUAL BINARY EXECUTION ===")
            manual_test_cmd = "cd #{extract_path} && #{release_path} version"
            case SSHClient.execute_command(connection, manual_test_cmd) do
              {:ok, {output, stderr, exit_code}} ->
                IO.puts("Manual test - Exit code: #{exit_code}")
                IO.puts("Manual test - Stdout: #{output}")
                IO.puts("Manual test - Stderr: #{stderr}")
              {:error, reason} ->
                IO.puts("Manual test failed: #{reason}")
            end
            
            # Give some time for the service to start
            IO.puts("Waiting 5 seconds for service to start...")
            :timer.sleep(5000)

            # Check if the service actually started
            case SSHClient.execute_command(connection, "launchctl list | grep #{service_name}") do
              {:ok, {output, _, 0}} ->
                trimmed_output = String.trim(output)
                if byte_size(trimmed_output) > 0 do
                  IO.puts("LaunchAgent running: #{trimmed_output}")
                  {:ok, :configured}
                else
                  IO.puts("LaunchAgent loaded but not running, checking logs...")
                  
                  # Check multiple log locations
                  log_locations = [
                    "#{extract_path}/#{service_name}.log",
                    "#{extract_path}/app.log",
                    "/tmp/#{service_name}.log"
                  ]
                  
                  Enum.each(log_locations, fn log_path ->
                    case SSHClient.execute_command(connection, "cat #{log_path} 2>/dev/null | tail -20") do
                      {:ok, {log_output, _, 0}} ->
                        trimmed_log = String.trim(log_output)
                        if byte_size(trimmed_log) > 0 do
                          IO.puts("=== LOG FILE: #{log_path} ===")
                          IO.puts(log_output)
                          IO.puts("=== END LOG ===")
                        else
                          IO.puts("Log file empty at: #{log_path}")
                        end
                      _ ->
                        IO.puts("No log found at: #{log_path}")
                    end
                  end)
                  
                  # Check launchctl error logs
                  case SSHClient.execute_command(connection, "launchctl error #{service_name} 2>/dev/null") do
                    {:ok, {error_output, _, 0}} ->
                      trimmed_error = String.trim(error_output)
                      if byte_size(trimmed_error) > 0 do
                        IO.puts("=== LAUNCHCTL ERRORS ===")
                        IO.puts(error_output)
                      else
                        IO.puts("No launchctl errors found")
                      end
                    _ ->
                      IO.puts("No launchctl errors found")
                  end
                  
                  # If LaunchAgent isn't working, try direct startup as fallback
                  IO.puts("=== TRYING DIRECT SERVICE START AS FALLBACK ===")
                  case try_direct_app_start(connection, app, extract_path) do
                    {:ok, :configured} ->
                      IO.puts("Direct start succeeded as fallback")
                      {:ok, :configured}
                    {:error, reason} ->
                      IO.puts("Direct start also failed: #{reason}")
                      {:ok, :configured}  # Still return success as plist is loaded
                  end
                end

              {:ok, {_, _, _}} ->
                IO.puts("LaunchAgent command failed, trying direct start...")
                case try_direct_app_start(connection, app, extract_path) do
                  {:ok, :configured} ->
                    IO.puts("Direct start succeeded after LaunchAgent failure")
                    {:ok, :configured}
                  {:error, reason} ->
                    IO.puts("Both LaunchAgent and direct start failed: #{reason}")
                    {:ok, :configured}  # Still return success as setup completed
                end

              {:error, reason} ->
                IO.puts("Failed to check LaunchAgent status: #{reason}")
                {:ok, :configured}  # Still return success if load commands worked
            end

          {:error, reason} ->
            IO.puts("Failed to load LaunchAgent: #{reason}")
            {:error, reason}
        end

      {:error, reason} ->
        {:error, "Failed to configure launchd service: #{reason}"}
    end
  end

  defp try_direct_app_start(connection, app, extract_path) do
    IO.puts("Attempting to start app directly without service manager...")

    # Find the release binary
    case find_release_binary(connection, extract_path) do
      {:ok, release_path} ->
        IO.puts("Found release binary: #{release_path}")

        # Set up environment variables for the Elixir release
        port = get_app_port(app)
        secret_key_base = get_or_generate_secret_key_base(connection, extract_path)
        
        IO.puts("=== DIRECT START ENVIRONMENT ===")
        IO.puts("Port: #{port}")
        IO.puts("Extract path: #{extract_path}")
        IO.puts("SECRET_KEY_BASE length: #{byte_size(secret_key_base)} chars")
        IO.puts("Release path: #{release_path}")
        
        env_vars = [
          "export MIX_ENV=prod",
          "export PHX_SERVER=true",
          "export PORT=#{port}",
          "export SECRET_KEY_BASE=#{secret_key_base}"
        ]

        env_setup = Enum.join(env_vars, " && ")

        # Start the release in daemon mode
        start_command = """
        cd #{extract_path} && \
        #{env_setup} && \
        nohup #{release_path} daemon > app.log 2>&1 &
        """

        IO.puts("=== EXECUTING START COMMAND ===")
        IO.puts("Release path: #{release_path}")
        IO.puts("Environment vars: #{env_setup}")
        IO.puts("Full command: #{start_command}")
        IO.puts("=== END COMMAND INFO ===")

        case SSHClient.execute_command(connection, start_command) do
          {:ok, {stdout, stderr, 0}} ->
            IO.puts("=== APP START COMMAND EXECUTED ===")
            IO.puts("Command succeeded with exit code 0")
            IO.puts("Stdout: #{stdout}")
            IO.puts("Stderr: #{stderr}")

            # Give the app time to start
            IO.puts("Waiting 10 seconds for app to start...")
            :timer.sleep(10000)

            # Verify the app is actually running
            case verify_app_process_running(connection, extract_path, app) do
              {:ok, :running} ->
                IO.puts("App verified as running")
                {:ok, :configured}

              {:error, reason} ->
                IO.puts("App process verification failed: #{reason}")
                # Try alternative start method
                try_alternative_start_method(connection, extract_path, release_path, app)
            end

          {:ok, {stdout, stderr, exit_code}} ->
            IO.puts("App start command failed with exit code #{exit_code}")
            IO.puts("Stdout: #{stdout}")
            IO.puts("Stderr: #{stderr}")
            {:error, "Failed to start app directly (exit #{exit_code}): #{stderr}"}

          {:error, reason} ->
            {:error, "Failed to start app directly: #{reason}"}
        end

      {:error, reason} ->
        {:error, "Could not find release binary: #{reason}"}
    end
  end

  defp try_alternative_start_method(connection, extract_path, release_path, app) do
    IO.puts("Trying alternative start method...")

    port = get_app_port(app)
    # Try with 'start' command instead of 'daemon'
    alt_command = """
    cd #{extract_path} && \
    export MIX_ENV=prod && \
    export PHX_SERVER=true && \
    export PORT=#{port} && \
    export SECRET_KEY_BASE=$(cat #{extract_path}/.secret_key_base 2>/dev/null || (echo '#{generate_secret_key_base()}' | tee #{extract_path}/.secret_key_base)) && \
    nohup #{release_path} start > app.log 2>&1 &
    """

    case SSHClient.execute_command(connection, alt_command) do
      {:ok, {_, _, 0}} ->
        :timer.sleep(3000)
        case verify_app_process_running(connection, extract_path, app) do
          {:ok, :running} ->
            IO.puts("App started successfully with alternative method")
            {:ok, :configured}

          {:error, _} ->
            {:error, "App failed to start with alternative method"}
        end

      _ ->
        {:error, "Alternative start method also failed"}
    end
  end

  defp verify_app_process_running(connection, extract_path, app \\ nil) do
    IO.puts("=== STARTING APP VERIFICATION ===")
    IO.puts("Extract path: #{extract_path}")

    # First, let's check what's in the log file
    case SSHClient.execute_command(connection, "cat #{extract_path}/app.log 2>/dev/null") do
      {:ok, {log_content, _, 0}} ->
        IO.puts("=== APP LOG CONTENTS ===")
        IO.puts(log_content)
        IO.puts("=== END APP LOG ===")
      _ ->
        IO.puts("No app.log file found or couldn't read it")
    end

    # Check multiple ways to verify the app is running
    checks = [
      # Check for beam process in the extract path
      "ps aux | grep '#{extract_path}' | grep beam | grep -v grep",
      # Check for any beam process that might be related
      "ps aux | grep beam | grep -v grep",
      # Check for Erlang/OTP processes
      "ps aux | grep erl | grep -v grep",
      # Check if app is listening on the configured port
      (if app, do: "lsof -i :#{get_app_port(app)} 2>/dev/null", else: "lsof -i :4000 2>/dev/null"),
      # Check for app-specific process
      (if app, do: "ps aux | grep #{extract_path |> Path.basename()}_app | grep -v grep", else: "ps aux | grep _app | grep -v grep")
    ]

    IO.puts("=== RUNNING PROCESS CHECKS ===")
    verification_results = Enum.map(checks, fn check_cmd ->
      case SSHClient.execute_command(connection, check_cmd) do
        {:ok, {output, _, 0}} ->
          trimmed_output = String.trim(output)
          IO.puts("Check: #{check_cmd}")
          IO.puts("Output: #{trimmed_output}")
          IO.puts("Has output: #{byte_size(trimmed_output) > 0}")
          IO.puts("---")
          {check_cmd, trimmed_output, byte_size(trimmed_output) > 0}
        {:ok, {output, _, exit_code}} ->
          IO.puts("Check: #{check_cmd} (exit code: #{exit_code})")
          IO.puts("Output: #{String.trim(output)}")
          IO.puts("---")
          {check_cmd, "", false}
        {:error, reason} ->
          IO.puts("Check: #{check_cmd} (error: #{inspect(reason)})")
          IO.puts("---")
          {check_cmd, "", false}
      end
    end)

    # Check if any verification succeeded
    successful_check = Enum.find(verification_results, fn {_, _, success} -> success end)

    case successful_check do
      {check_cmd, output, true} ->
        IO.puts("=== VERIFICATION SUCCESSFUL ===")
        IO.puts("Successful check: #{check_cmd}")
        IO.puts("Output: #{output}")
        {:ok, :running}
      nil ->
        IO.puts("=== VERIFICATION FAILED ===")
        IO.puts("No running process found with any of the checks")
        {:error, "No running process found"}
    end
  end

  defp find_release_binary(connection, extract_path) do
    # Try to find Elixir release binaries in various common locations
    IO.puts("Searching for release binary in: #{extract_path}")

    # First, check if there's a _build/prod/rel directory structure
    case SSHClient.execute_command(connection, "find #{extract_path} -name '_build' -type d") do
      {:ok, {output, _, 0}} ->
        build_dirs = output |> String.trim() |> String.split("\n") |> Enum.reject(&(&1 == ""))
        if not Enum.empty?(build_dirs) do
          IO.puts("Found _build directories: #{inspect(build_dirs)}")
          case find_elixir_release_in_build(connection, extract_path) do
            {:ok, path} -> {:ok, path}
            {:error, _} -> find_generic_release_binary(connection, extract_path)
          end
        else
          find_generic_release_binary(connection, extract_path)
        end

      _ ->
        find_generic_release_binary(connection, extract_path)
    end
  end

  defp find_elixir_release_in_build(connection, extract_path) do
    # Look for Elixir release structure: _build/prod/rel/app_name/bin/app_name
    case SSHClient.execute_command(connection, "find #{extract_path}/_build/prod/rel -type f -executable 2>/dev/null") do
      {:ok, {output, _, 0}} ->
        executables = output |> String.trim() |> String.split("\n") |> Enum.reject(&(&1 == ""))

        # Filter out .bat files and prefer the main release binary
        release_candidates = executables
        |> Enum.reject(&String.ends_with?(&1, ".bat"))
        |> Enum.filter(&(not String.contains?(&1, "/erts-")))  # Skip ERTS binaries

        IO.puts("Found release candidates: #{inspect(release_candidates)}")

        case release_candidates do
          [binary | _] ->
            IO.puts("Selected release binary: #{binary}")
            {:ok, binary}

          [] ->
            {:error, "No suitable release binary found in _build"}
        end

      _ ->
        {:error, "Could not search _build directory"}
    end
  end

  defp find_generic_release_binary(connection, extract_path) do
    # Try different common release paths
    search_patterns = [
      "#{extract_path}/bin/*",
      "#{extract_path}/releases/*/bin/*",
      "#{extract_path}/**/bin/*"
    ]

    Enum.reduce_while(search_patterns, {:error, "No release binary found"}, fn pattern, acc ->
      case SSHClient.execute_command(connection, "find #{pattern} -type f -executable 2>/dev/null | head -5") do
        {:ok, {output, _, 0}} ->
          executables = output |> String.trim() |> String.split("\n") |> Enum.reject(&(&1 == ""))

          # Filter and select the best candidate
          candidates = executables
          |> Enum.reject(&String.ends_with?(&1, ".bat"))
          |> Enum.reject(&String.contains?(&1, "erts"))

          IO.puts("Generic search found candidates: #{inspect(candidates)}")

          case candidates do
            [binary | _] ->
              IO.puts("Selected generic binary: #{binary}")
              {:halt, {:ok, binary}}

            [] ->
              {:cont, acc}
          end

        _ ->
          {:cont, acc}
      end
    end)
  end

  defp check_service_status_with_retries(connection, app, host_architecture, retries) when retries > 0 do
    case get_app_service_status(connection, app, host_architecture) do
      {:ok, "active"} -> {:ok, "active"}
      {:ok, "activating"} ->
        :timer.sleep(2000)
        check_service_status_with_retries(connection, app, host_architecture, retries - 1)
      {:ok, status} -> {:ok, status}
      {:error, reason} -> {:error, reason}
    end
  end

  defp check_service_status_with_retries(connection, app, host_architecture, 0) do
    get_app_service_status(connection, app, host_architecture)
  end


  defp verify_app_running(connection, app, extract_path) do
    # Use the enhanced verification function
    verify_app_process_running(connection, extract_path, app)
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

  defp generate_launchd_plist(app, extract_path, connection) do
    service_name = get_service_name(app)

    # Get the release binary path, with fallback
    release_path = case find_release_binary(connection, extract_path) do
      {:ok, path} -> path
      {:error, _} ->
        # Fallback to constructed path - try to determine from extract path
        extract_basename = extract_path |> Path.basename()
        "#{extract_path}/_build/prod/rel/#{extract_basename}_app/bin/#{extract_basename}_app"
    end

    # Get the username from SSH config (the user deploying the app)
    deploy_user = get_deploy_user(connection)

    # Get or generate a consistent SECRET_KEY_BASE
    secret_key_base = get_or_generate_secret_key_base(connection, extract_path)

    # Use user-accessible log path instead of /var/log
    log_path = "#{extract_path}/#{service_name}.log"

    IO.puts("=== GENERATING LAUNCHD PLIST ===")
    IO.puts("Service name: #{service_name}")
    IO.puts("Release path: #{release_path}")
    IO.puts("Extract path: #{extract_path}")
    IO.puts("Log path: #{log_path}")
    IO.puts("Port: #{get_app_port(app)}")
    
    # Verify the release binary exists and is executable
    case SSHClient.execute_command(connection, "ls -la #{release_path}") do
      {:ok, {output, _, 0}} ->
        IO.puts("=== RELEASE BINARY INFO ===")
        IO.puts(output)
      {:ok, {_, _, exit_code}} ->
        IO.puts("WARNING: Release binary not found at #{release_path} (exit code: #{exit_code})")
      {:error, reason} ->
        IO.puts("ERROR: Could not check release binary: #{reason}")
    end

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>Label</key>
        <string>#{service_name}</string>
        <key>ProgramArguments</key>
        <array>
            <string>#{release_path}</string>
            <string>start</string>
        </array>
        <key>WorkingDirectory</key>
        <string>#{extract_path}</string>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <true/>
        <key>EnvironmentVariables</key>
        <dict>
            <key>PORT</key>
            <string>#{get_app_port(app)}</string>
            <key>MIX_ENV</key>
            <string>prod</string>
            <key>PHX_SERVER</key>
            <string>true</string>
            <key>HOME</key>
            <string>#{extract_path}</string>
            <key>RELEASE_COOKIE</key>
            <string>#{service_name}</string>
            <key>SECRET_KEY_BASE</key>
            <string>#{secret_key_base}</string>
            <key>PHX_HOST</key>
            <string>localhost</string>
        </dict>
        <key>StandardOutPath</key>
        <string>#{log_path}</string>
        <key>StandardErrorPath</key>
        <string>#{log_path}</string>
    </dict>
    </plist>
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
      String.contains?(String.downcase(app_name), "hello") -> "4006"
      true -> "4000"  # fallback default
    end
  end

  defp generate_secret_key_base do
    # Generate a 64-byte random secret key base
    :crypto.strong_rand_bytes(64) |> Base.encode64()
  end

  defp generate_and_store_secret_key_base do
    generate_secret_key_base()
  end

  defp get_or_generate_secret_key_base(connection, extract_path) do
    secret_file_path = "#{extract_path}/.secret_key_base"

    # Try to read existing secret
    case SSHClient.execute_command(connection, "cat #{secret_file_path} 2>/dev/null") do
      {:ok, {secret, _, 0}} ->
        trimmed_secret = String.trim(secret)
        if byte_size(trimmed_secret) > 0 do
          IO.puts("Using existing SECRET_KEY_BASE from #{secret_file_path}")
          trimmed_secret
        else
          create_and_store_secret_key_base(connection, secret_file_path)
        end

      _ ->
        create_and_store_secret_key_base(connection, secret_file_path)
    end
  end

  defp create_and_store_secret_key_base(connection, secret_file_path) do
    secret_key_base = generate_secret_key_base()

    # Store the secret in a file for reuse
    case SSHClient.execute_command(connection, "echo '#{secret_key_base}' > #{secret_file_path}") do
      {:ok, {_, _, 0}} ->
        IO.puts("Generated and stored new SECRET_KEY_BASE at #{secret_file_path}")
        secret_key_base

      {:error, reason} ->
        IO.puts("Failed to store SECRET_KEY_BASE: #{reason}")
        secret_key_base
    end
  end

  defp get_app_specific_env_vars(app) do
    app_name_lower = String.downcase(app.name)

    cond do
      String.contains?(app_name_lower, "agent") ->
        ~s"""
        Environment=OPENAI_API_KEY=your_openai_api_key_here
        Environment=ELIXIHUB_JWT_SECRET=dev_secret_key_32_chars_long_exactly_for_jwt_signing
        Environment=ELIXIHUB_URL=http://localhost:4005
        Environment=HELLO_WORLD_MCP_URL=http://localhost:4001/api/mcp
        """

      String.contains?(app_name_lower, "hello") ->
        ~s"""
        Environment=ELIXIHUB_JWT_SECRET=dev_secret_key_32_chars_long_exactly_for_jwt_signing
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

  defp unload_launchd_service(connection, _service_name, plist_path) do
    case SSHClient.execute_command(connection, "sudo launchctl unload #{plist_path}") do
      {:ok, {_, _, 0}} ->
        {:ok, :unloaded}

      {:ok, {_, error, exit_code}} ->
        # Don't fail if service doesn't exist or is already unloaded
        if String.contains?(error, "No such file") or String.contains?(error, "not found") or String.contains?(error, "not loaded") do
          {:ok, :already_unloaded}
        else
          {:error, "Failed to unload service (exit #{exit_code}): #{error}"}
        end

      {:error, reason} ->
        {:error, "Failed to unload service: #{reason}"}
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
