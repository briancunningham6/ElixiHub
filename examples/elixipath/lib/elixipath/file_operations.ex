defmodule ElixiPath.FileOperations do
  @moduledoc """
  Core file operations for ElixiPath with security controls
  """
  require Logger
  import Bitwise

  @max_file_size 100 * 1024 * 1024 # 100MB
  @allowed_mime_types [
    "text/plain", "text/csv", "text/json", "application/json",
    "image/jpeg", "image/png", "image/gif", "image/webp",
    "application/pdf", "application/zip",
    "application/vnd.ms-excel", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  ]

  def list_files(user_email, relative_path \\ "", app_name \\ nil) do
    Logger.info("Listing files for user: #{user_email}, path: #{relative_path}, app: #{app_name}")
    
    case build_full_path(user_email, relative_path, app_name) do
      {:ok, full_path} ->
        case File.ls(full_path) do
          {:ok, files} ->
            file_list = Enum.map(files, fn filename ->
              file_path = Path.join(full_path, filename)
              get_file_metadata(file_path, filename)
            end)
            |> Enum.sort_by(& &1.name)
            
            {:ok, file_list}
          
          {:error, reason} ->
            Logger.warning("Failed to list directory #{full_path}: #{reason}")
            {:error, "Directory not accessible: #{reason}"}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  def upload_file(user_email, relative_path, base64_content, app_name) do
    Logger.info("Uploading file for user: #{user_email}, path: #{relative_path}, app: #{app_name}")
    
    with {:ok, content} <- decode_base64_content(base64_content),
         :ok <- validate_file_size(content),
         :ok <- validate_mime_type(relative_path, content),
         {:ok, full_path} <- build_full_path(user_email, relative_path, app_name),
         :ok <- ensure_parent_directory(full_path),
         :ok <- File.write(full_path, content) do
      
      Logger.info("File uploaded successfully: #{full_path}")
      file_info = get_file_metadata(full_path, Path.basename(relative_path))
      {:ok, file_info}
    else
      {:error, reason} ->
        Logger.warning("Failed to upload file: #{reason}")
        {:error, reason}
    end
  end

  def delete_file(user_email, relative_path) do
    Logger.info("Deleting file for user: #{user_email}, path: #{relative_path}")
    
    case build_full_path(user_email, relative_path, nil) do
      {:ok, full_path} ->
        cond do
          File.regular?(full_path) ->
            case File.rm(full_path) do
              :ok -> 
                Logger.info("File deleted: #{full_path}")
                :ok
              {:error, reason} -> 
                {:error, "Failed to delete file: #{reason}"}
            end
          
          File.dir?(full_path) ->
            case File.rm_rf(full_path) do
              {:ok, _} -> 
                Logger.info("Directory deleted: #{full_path}")
                :ok
              {:error, reason} -> 
                {:error, "Failed to delete directory: #{reason}"}
            end
          
          true ->
            {:error, "File or directory does not exist"}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_file_info(user_email, relative_path) do
    case build_full_path(user_email, relative_path, nil) do
      {:ok, full_path} ->
        if File.exists?(full_path) do
          filename = Path.basename(relative_path)
          file_info = get_file_metadata(full_path, filename)
          {:ok, file_info}
        else
          {:error, "File does not exist"}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  def create_directory(user_email, relative_path, app_name) do
    Logger.info("Creating directory for user: #{user_email}, path: #{relative_path}, app: #{app_name}")
    
    case build_full_path(user_email, relative_path, app_name) do
      {:ok, full_path} ->
        case File.mkdir_p(full_path) do
          :ok ->
            Logger.info("Directory created: #{full_path}")
            dir_info = get_file_metadata(full_path, Path.basename(relative_path))
            {:ok, dir_info}
          
          {:error, reason} ->
            {:error, "Failed to create directory: #{reason}"}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_storage_usage(user_email) do
    Logger.info("Getting storage usage for user: #{user_email}")
    
    user_dirs = ElixiPath.Auth.get_user_directories(user_email)
    
    shared_usage = calculate_directory_size(user_dirs.shared)
    user_usage = calculate_directory_size(user_dirs.user_root)
    
    {:ok, %{
      user_email: user_email,
      shared_usage_bytes: shared_usage,
      user_usage_bytes: user_usage,
      total_usage_bytes: shared_usage + user_usage,
      shared_usage_mb: Float.round(shared_usage / (1024 * 1024), 2),
      user_usage_mb: Float.round(user_usage / (1024 * 1024), 2),
      total_usage_mb: Float.round((shared_usage + user_usage) / (1024 * 1024), 2)
    }}
  end

  # Private helper functions

  defp build_full_path(user_email, relative_path, app_name) do
    user_dirs = ElixiPath.Auth.get_user_directories(user_email)
    
    # Determine base path
    base_path = cond do
      app_name && String.starts_with?(relative_path, "shared/") ->
        Path.join(user_dirs.shared, app_name)
      
      app_name ->
        Path.join(user_dirs.user_root, app_name)
      
      String.starts_with?(relative_path, "shared/") ->
        user_dirs.shared
      
      true ->
        user_dirs.user_root
    end
    
    # Remove shared/ prefix if present
    clean_path = String.replace_prefix(relative_path, "shared/", "")
    
    full_path = if clean_path == "" do
      base_path
    else
      Path.join(base_path, clean_path)
    end
    
    # Validate path is within allowed directories
    case ElixiPath.Auth.validate_file_path(full_path, user_email) do
      {:ok, validated_path} -> {:ok, validated_path}
      {:error, reason} -> {:error, reason}
    end
  end

  defp decode_base64_content(base64_content) do
    case Base.decode64(base64_content) do
      {:ok, content} -> {:ok, content}
      :error -> {:error, "Invalid base64 content"}
    end
  end

  defp validate_file_size(content) do
    size = byte_size(content)
    if size <= @max_file_size do
      :ok
    else
      {:error, "File size #{size} bytes exceeds maximum allowed size of #{@max_file_size} bytes"}
    end
  end

  defp validate_mime_type(filename, content) do
    # Basic MIME type detection based on file extension and content
    extension = Path.extname(filename) |> String.downcase()
    
    mime_type = case extension do
      ".txt" -> "text/plain"
      ".json" -> "application/json"
      ".csv" -> "text/csv"
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg" 
      ".png" -> "image/png"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      ".pdf" -> "application/pdf"
      ".zip" -> "application/zip"
      ".xls" -> "application/vnd.ms-excel"
      ".xlsx" -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      _ -> detect_mime_from_content(content)
    end
    
    if mime_type in @allowed_mime_types do
      :ok
    else
      {:error, "File type #{mime_type} is not allowed"}
    end
  end

  defp detect_mime_from_content(content) do
    case content do
      <<0xFF, 0xD8, 0xFF, _::binary>> -> "image/jpeg"
      <<0x89, 0x50, 0x4E, 0x47, _::binary>> -> "image/png"
      <<0x47, 0x49, 0x46, _::binary>> -> "image/gif"
      <<0x25, 0x50, 0x44, 0x46, _::binary>> -> "application/pdf"
      _ -> "application/octet-stream"
    end
  end

  defp ensure_parent_directory(file_path) do
    parent_dir = Path.dirname(file_path)
    case File.mkdir_p(parent_dir) do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to create parent directory: #{reason}"}
    end
  end

  defp get_file_metadata(file_path, filename) do
    stat = File.stat!(file_path)
    
    %{
      name: filename,
      path: file_path,
      type: if(stat.type == :directory, do: "directory", else: "file"),
      size: stat.size,
      modified_at: stat.mtime |> NaiveDateTime.from_erl!() |> DateTime.from_naive!("Etc/UTC"),
      permissions: format_permissions(stat.mode)
    }
  end

  defp format_permissions(mode) do
    # Convert file mode to readable string
    owner = case (mode &&& 0o700) >>> 6 do
      7 -> "rwx"
      6 -> "rw-"
      5 -> "r-x"
      4 -> "r--"
      3 -> "-wx"
      2 -> "-w-"
      1 -> "--x"
      0 -> "---"
    end
    
    group = case (mode &&& 0o070) >>> 3 do
      7 -> "rwx"
      6 -> "rw-"
      5 -> "r-x"
      4 -> "r--"
      3 -> "-wx"
      2 -> "-w-"
      1 -> "--x"
      0 -> "---"
    end
    
    other = case mode &&& 0o007 do
      7 -> "rwx"
      6 -> "rw-"
      5 -> "r-x"
      4 -> "r--"
      3 -> "-wx"
      2 -> "-w-"
      1 -> "--x"
      0 -> "---"
    end
    
    owner <> group <> other
  end

  defp calculate_directory_size(dir_path) do
    if File.exists?(dir_path) do
      case File.ls(dir_path) do
        {:ok, files} ->
          Enum.reduce(files, 0, fn file, acc ->
            file_path = Path.join(dir_path, file)
            case File.stat(file_path) do
              {:ok, %{type: :directory}} ->
                acc + calculate_directory_size(file_path)
              {:ok, %{size: size}} ->
                acc + size
              _ ->
                acc
            end
          end)
        _ ->
          0
      end
    else
      0
    end
  end
end