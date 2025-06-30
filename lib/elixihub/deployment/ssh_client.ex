defmodule Elixihub.Deployment.SSHClient do
  @moduledoc """
  SSH client for connecting to remote servers for deployment.
  """

  @default_port 22
  @default_timeout 30_000

  @doc """
  Connects to a remote server via SSH.
  
  ## Parameters
  - config: SSH configuration map
    - host: Target server hostname/IP
    - port: SSH port (default: 22)
    - username: SSH username
    - password: SSH password (optional if using key)
    - private_key: SSH private key path (optional)
    - timeout: Connection timeout in ms (default: 30000)
  
  ## Returns
  - {:ok, connection} on success
  - {:error, reason} on failure
  """
  def connect(config) do
    # Validate required configuration
    case validate_ssh_config(config) do
      {:ok, validated_config} ->
        host = String.to_charlist(validated_config.host)
        port = Map.get(validated_config, :port, @default_port)
        username = String.to_charlist(validated_config.username)
        timeout = Map.get(validated_config, :timeout, @default_timeout)

        ssh_opts = build_ssh_options(validated_config)

        case :ssh.connect(host, port, ssh_opts, timeout) do
          {:ok, connection} ->
            {:ok, connection}
          
          {:error, reason} ->
            {:error, "SSH connection failed: #{inspect(reason)}"}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Disconnects from the SSH server.
  """
  def disconnect(connection) do
    case :ssh.close(connection) do
      :ok -> {:ok, :disconnected}
      {:error, reason} -> {:error, "Disconnect failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Executes a command on the remote server.
  
  ## Parameters
  - connection: SSH connection
  - command: Command to execute
  - opts: Options (timeout, etc.)
  
  ## Returns
  - {:ok, {stdout, stderr, exit_code}} on success
  - {:error, reason} on failure
  """
  def execute_command(connection, command, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    command_charlist = String.to_charlist(command)
    
    case :ssh_connection.session_channel(connection, timeout) do
      {:ok, channel} ->
        case :ssh_connection.exec(connection, channel, command_charlist, timeout) do
          :success ->
            result = collect_response(connection, channel, "", "", nil)
            :ssh_connection.close(connection, channel)
            result
          
          :failure ->
            :ssh_connection.close(connection, channel)
            {:error, "Command execution failed"}
        end
      
      {:error, reason} ->
        {:error, "Failed to open SSH channel: #{inspect(reason)}"}
    end
  end

  @doc """
  Uploads a file to the remote server using SFTP.
  
  ## Parameters
  - connection: SSH connection
  - local_path: Local file path
  - remote_path: Remote destination path
  
  ## Returns
  - {:ok, remote_path} on success
  - {:error, reason} on failure
  """
  def upload_file(connection, local_path, remote_path) do
    case :ssh_sftp.start_channel(connection) do
      {:ok, sftp_channel} ->
        result = case :ssh_sftp.write_file(sftp_channel, String.to_charlist(remote_path), File.read!(local_path)) do
          :ok ->
            {:ok, remote_path}
          
          {:error, reason} ->
            {:error, "File upload failed: #{inspect(reason)}"}
        end
        
        :ssh_sftp.stop_channel(sftp_channel)
        result
      
      {:error, reason} ->
        {:error, "Failed to start SFTP channel: #{inspect(reason)}"}
    end
  end

  @doc """
  Downloads a file from the remote server using SFTP.
  
  ## Parameters
  - connection: SSH connection
  - remote_path: Remote file path
  - local_path: Local destination path
  
  ## Returns
  - {:ok, local_path} on success
  - {:error, reason} on failure
  """
  def download_file(connection, remote_path, local_path) do
    case :ssh_sftp.start_channel(connection) do
      {:ok, sftp_channel} ->
        result = case :ssh_sftp.read_file(sftp_channel, String.to_charlist(remote_path)) do
          {:ok, data} ->
            case File.write(local_path, data) do
              :ok -> {:ok, local_path}
              {:error, reason} -> {:error, "Failed to write local file: #{inspect(reason)}"}
            end
          
          {:error, reason} ->
            {:error, "File download failed: #{inspect(reason)}"}
        end
        
        :ssh_sftp.stop_channel(sftp_channel)
        result
      
      {:error, reason} ->
        {:error, "Failed to start SFTP channel: #{inspect(reason)}"}
    end
  end

  @doc """
  Creates a directory on the remote server.
  """
  def create_directory(connection, path) do
    execute_command(connection, "mkdir -p #{path}")
  end

  @doc """
  Checks if a path exists on the remote server.
  """
  def path_exists?(connection, path) do
    case execute_command(connection, "test -e #{path}") do
      {:ok, {_, _, 0}} -> true
      _ -> false
    end
  end

  @doc """
  Gets file permissions on the remote server.
  """
  def get_permissions(connection, path) do
    case execute_command(connection, "stat -c '%a' #{path}") do
      {:ok, {permissions, _, 0}} ->
        {:ok, String.trim(permissions)}
      
      {:ok, {_, error, exit_code}} ->
        {:error, "Failed to get permissions (exit #{exit_code}): #{error}"}
    end
  end

  @doc """
  Sets file permissions on the remote server.
  """
  def set_permissions(connection, path, mode) do
    case execute_command(connection, "chmod #{mode} #{path}") do
      {:ok, {_, _, 0}} ->
        {:ok, :permissions_set}
      
      {:ok, {_, error, exit_code}} ->
        {:error, "Failed to set permissions (exit #{exit_code}): #{error}"}
    end
  end

  # Private functions

  defp build_ssh_options(config) do
    base_opts = [
      silently_accept_hosts: true,
      user_interaction: false,
      user: String.to_charlist(config.username)
    ]

    cond do
      Map.has_key?(config, :private_key) ->
        user_dir = config.private_key |> Path.dirname() |> String.to_charlist()
        [{:user_dir, user_dir} | base_opts]
      
      Map.has_key?(config, :password) and config.password != "" ->
        password = String.to_charlist(config.password)
        [{:password, password} | base_opts]
      
      true ->
        # For connection tests without authentication, set auth_methods to none
        [{:auth_methods, ['none']} | base_opts]
    end
  end

  defp collect_response(connection, channel, stdout, stderr, exit_code) do
    receive do
      {:ssh_cm, ^connection, {:data, ^channel, 0, data}} ->
        collect_response(connection, channel, stdout <> to_string(data), stderr, exit_code)
      
      {:ssh_cm, ^connection, {:data, ^channel, 1, data}} ->
        collect_response(connection, channel, stdout, stderr <> to_string(data), exit_code)
      
      {:ssh_cm, ^connection, {:exit_status, ^channel, status}} ->
        collect_response(connection, channel, stdout, stderr, status)
      
      {:ssh_cm, ^connection, {:closed, ^channel}} ->
        {:ok, {stdout, stderr, exit_code || 0}}
    after
      30_000 ->
        {:error, "Command execution timeout"}
    end
  end

  defp validate_ssh_config(config) do
    cond do
      is_nil(config.host) or config.host == "" ->
        {:error, "SSH host is required"}
      
      is_nil(config.username) or config.username == "" ->
        {:error, "SSH username is required"}
      
      true ->
        {:ok, config}
    end
  end
end