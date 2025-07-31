defmodule ElixiPath.Auth do
  @moduledoc """
  Authentication utilities for ElixiPath
  """
  require Logger

  def verify_token(token) when is_binary(token) do
    # Use same JWT verification as other apps
    case ElixiPath.Auth.JWTVerifier.verify(token) do
      {:ok, claims} ->
        user = %{
          user_id: claims["sub"],
          email: claims["email"],
          username: claims["username"] || claims["email"],
          roles: claims["roles"] || []
        }
        {:ok, user}
      
      {:error, reason} ->
        Logger.warning("Token verification failed: #{inspect(reason)}")
        {:error, :invalid_token}
    end
  end

  def verify_token(_), do: {:error, :invalid_token}

  def get_user_directories(user_email) do
    base_path = Path.join([System.user_home(), "elixipath"])
    
    %{
      shared: "#{base_path}/shared",
      user_root: "#{base_path}/users/#{user_email}",
      accessible_paths: [
        "#{base_path}/shared",
        "#{base_path}/users/#{user_email}"
      ]
    }
  end

  def validate_file_path(path, user_email) do
    user_dirs = get_user_directories(user_email)
    normalized_path = Path.expand(path)
    
    # Check if path is within allowed directories
    allowed = Enum.any?(user_dirs.accessible_paths, fn allowed_path ->
      String.starts_with?(normalized_path, Path.expand(allowed_path))
    end)
    
    if allowed do
      {:ok, normalized_path}
    else
      {:error, :forbidden_path}
    end
  end

  def ensure_user_directories(user_email) do
    dirs = get_user_directories(user_email)
    
    # Create user-specific directories
    File.mkdir_p!(dirs.user_root)
    
    # Create app-specific directories for this user
    apps = ["agent_app", "task_manager", "hello_world_app"]
    Enum.each(apps, fn app ->
      File.mkdir_p!("#{dirs.user_root}/#{app}")
    end)
    
    dirs
  end
end