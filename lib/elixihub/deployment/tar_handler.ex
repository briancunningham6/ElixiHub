defmodule Elixihub.Deployment.TarHandler do
  @moduledoc """
  Handles tar file upload and extraction for deployments.
  """

  alias Elixihub.Deployment.SSHClient

  @doc """
  Uploads a tar file to the remote server and extracts it.
  
  ## Parameters
  - connection: SSH connection
  - tar_path: Local path to the tar file
  - remote_deploy_path: Remote path where the app should be deployed
  
  ## Returns
  - {:ok, extract_path} on success
  - {:error, reason} on failure
  """
  def upload_and_extract(connection, tar_path, remote_deploy_path) do
    with {:ok, _} <- validate_tar_file(tar_path),
         {:ok, remote_tar_path} <- upload_tar_file(connection, tar_path, remote_deploy_path),
         {:ok, extract_path} <- extract_tar_file(connection, remote_tar_path, remote_deploy_path),
         {:ok, _} <- cleanup_tar_file(connection, remote_tar_path) do
      {:ok, extract_path}
    else
      {:error, reason} = error ->
        cleanup_tar_file(connection, Path.join(remote_deploy_path, Path.basename(tar_path)))
        error
    end
  end

  @doc """
  Validates that the tar file exists and is a valid tar archive.
  """
  def validate_tar_file(tar_path) do
    case File.stat(tar_path) do
      {:ok, %File.Stat{type: :regular}} ->
        basename = Path.basename(tar_path)
        cond do
          String.ends_with?(basename, ".tar") -> validate_tar_contents(tar_path)
          String.ends_with?(basename, ".tgz") -> validate_tar_contents(tar_path)
          String.ends_with?(basename, ".tar.gz") -> validate_tar_contents(tar_path)
          String.ends_with?(basename, ".gz") -> validate_tar_contents(tar_path)
          true -> {:error, "File must be a .tar, .tgz, .tar.gz, or .gz archive"}
        end
      
      {:ok, %File.Stat{type: type}} ->
        {:error, "Expected regular file, got #{type}"}
      
      {:error, reason} ->
        {:error, "Cannot access tar file: #{inspect(reason)}"}
    end
  end

  @doc """
  Lists the contents of a tar file without extracting it.
  """
  def list_tar_contents(tar_path) do
    case :erl_tar.table(String.to_charlist(tar_path)) do
      {:ok, files} ->
        file_list = Enum.map(files, &to_string/1)
        {:ok, file_list}
      
      {:error, reason} ->
        {:error, "Failed to read tar contents: #{inspect(reason)}"}
    end
  end

  @doc """
  Creates a backup of the current deployment before replacing it.
  """
  def create_backup(connection, deploy_path) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
    backup_path = "#{deploy_path}.backup.#{timestamp}"
    
    case SSHClient.path_exists?(connection, deploy_path) do
      true ->
        case SSHClient.execute_command(connection, "cp -r #{deploy_path} #{backup_path}") do
          {:ok, {_, _, 0}} ->
            {:ok, backup_path}
          
          {:ok, {_, error, exit_code}} ->
            {:error, "Failed to create backup (exit #{exit_code}): #{error}"}
        end
      
      false ->
        {:ok, :no_backup_needed}
    end
  end

  @doc """
  Restores a backup deployment.
  """
  def restore_backup(connection, backup_path, deploy_path) do
    case SSHClient.execute_command(connection, "rm -rf #{deploy_path} && mv #{backup_path} #{deploy_path}") do
      {:ok, {_, _, 0}} ->
        {:ok, deploy_path}
      
      {:ok, {_, error, exit_code}} ->
        {:error, "Failed to restore backup (exit #{exit_code}): #{error}"}
    end
  end

  @doc """
  Cleans up old backup files.
  """
  def cleanup_old_backups(connection, deploy_path, keep_count \\ 5) do
    backup_pattern = "#{deploy_path}.backup.*"
    
    case SSHClient.execute_command(connection, "ls -t #{backup_pattern} 2>/dev/null | tail -n +#{keep_count + 1} | xargs rm -rf") do
      {:ok, {_, _, _}} ->
        {:ok, :cleanup_completed}
      
      {:error, reason} ->
        {:error, "Failed to cleanup backups: #{reason}"}
    end
  end

  # Private functions

  defp upload_tar_file(connection, local_tar_path, remote_deploy_path) do
    filename = Path.basename(local_tar_path)
    remote_tar_path = Path.join(remote_deploy_path, filename)
    
    # Ensure the remote directory exists
    case SSHClient.create_directory(connection, remote_deploy_path) do
      {:ok, {_, _, 0}} ->
        SSHClient.upload_file(connection, local_tar_path, remote_tar_path)
      
      {:ok, {_, error, exit_code}} ->
        {:error, "Failed to create remote directory (exit #{exit_code}): #{error}"}
      
      {:error, reason} ->
        {:error, "Failed to create remote directory: #{reason}"}
    end
  end

  defp extract_tar_file(connection, remote_tar_path, remote_deploy_path) do
    extract_path = Path.join(remote_deploy_path, "app")
    
    # Create extraction directory
    case SSHClient.create_directory(connection, extract_path) do
      {:ok, {_, _, 0}} ->
        # Extract the tar file
        extract_command = build_extract_command(remote_tar_path, extract_path)
        
        case SSHClient.execute_command(connection, extract_command) do
          {:ok, {_, _, 0}} ->
            {:ok, extract_path}
          
          {:ok, {_, error, exit_code}} ->
            {:error, "Failed to extract tar file (exit #{exit_code}): #{error}"}
          
          {:error, reason} ->
            {:error, "Failed to extract tar file: #{reason}"}
        end
      
      {:ok, {_, error, exit_code}} ->
        {:error, "Failed to create extraction directory (exit #{exit_code}): #{error}"}
      
      {:error, reason} ->
        {:error, "Failed to create extraction directory: #{reason}"}
    end
  end

  defp cleanup_tar_file(connection, remote_tar_path) do
    case SSHClient.execute_command(connection, "rm -f #{remote_tar_path}") do
      {:ok, {_, _, 0}} ->
        {:ok, :cleanup_completed}
      
      {:ok, {_, error, exit_code}} ->
        {:error, "Failed to cleanup tar file (exit #{exit_code}): #{error}"}
      
      {:error, reason} ->
        {:error, "Failed to cleanup tar file: #{reason}"}
    end
  end

  defp build_extract_command(tar_path, extract_path) do
    basename = Path.basename(tar_path)
    cond do
      String.ends_with?(basename, ".tar.gz") ->
        "tar -xzf #{tar_path} -C #{extract_path}"
      
      String.ends_with?(basename, ".tgz") ->
        "tar -xzf #{tar_path} -C #{extract_path}"
      
      String.ends_with?(basename, ".tar") ->
        "tar -xf #{tar_path} -C #{extract_path}"
      
      String.ends_with?(basename, ".gz") ->
        "tar -xzf #{tar_path} -C #{extract_path}"
      
      true ->
        "tar -xf #{tar_path} -C #{extract_path}"
    end
  end

  defp validate_tar_contents(tar_path) do
    case list_tar_contents(tar_path) do
      {:ok, files} ->
        if length(files) > 0 do
          {:ok, files}
        else
          {:error, "Tar file is empty"}
        end
      
      {:error, reason} ->
        {:error, "Invalid tar file: #{reason}"}
    end
  end
end