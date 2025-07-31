defmodule HelloWorldApp.Auth.ElixiHubAuth do
  @moduledoc """
  Reusable ElixiHub authentication library for Phoenix applications.
  
  This module provides:
  - JWT token verification using ElixiHub's shared secret
  - Session-based authentication plug
  - SSO controller for handling ElixiHub redirects
  - User directory management helpers
  
  ## Usage
  
  1. Add to your router:
     ```elixir
     pipeline :browser do
       plug :accepts, ["html"]
       plug :fetch_session
       plug :fetch_live_flash
       plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
       plug :protect_from_forgery
       plug :put_secure_browser_headers
       plug HelloWorldApp.Auth.ElixiHubAuth.SessionAuth
     end
     ```
  
  2. Add SSO routes:
     ```elixir
     scope "/", MyAppWeb do
       pipe_through :browser
       get "/sso/authenticate", SSOController, :authenticate
       get "/sso/logout", SSOController, :logout
     end
     ```
  
  3. Handle SSO tokens in your home controller:
     ```elixir
     def home(conn, %{"sso_token" => _token} = params) do
       redirect(conn, to: "/sso/authenticate?" <> URI.encode_query(params))
     end
     ```
  """

  @doc """
  Gets the ElixiHub shared secret from application config or environment.
  
  Configure in your config files:
  ```elixir
  config :my_app, :elixihub_auth,
    shared_secret: "dev_secret_key_32_chars_long_exactly_for_jwt_signing",
    elixihub_url: "http://localhost:4005"
  ```
  """
  def get_shared_secret do
    Application.get_env(:hello_world_app, :elixihub_auth)[:shared_secret] ||
      "dev_secret_key_32_chars_long_exactly_for_jwt_signing"
  end

  @doc """
  Gets the ElixiHub base URL from application config.
  """
  def get_elixihub_url do
    Application.get_env(:hello_world_app, :elixihub_auth)[:elixihub_url] ||
      "http://localhost:4005"
  end

  @doc """
  Gets the current app name for SSO redirects.
  """
  def get_app_name do
    Application.get_env(:hello_world_app, :elixihub_auth)[:app_name] ||
      "HelloWorldApp"
  end

  @doc """
  Verifies a JWT token from ElixiHub and returns user information.
  
  ## Returns
  - `{:ok, user}` - Token is valid, returns user map
  - `{:error, reason}` - Token is invalid or expired
  
  ## Example
      iex> ElixiHubAuth.verify_token(token)
      {:ok, %{user_id: "3", email: "user@example.com", username: "user@example.com", roles: []}}
  """
  def verify_token(token) when is_binary(token) do
    case HelloWorldApp.Auth.ElixiHubAuth.JWTVerifier.verify(token) do
      {:ok, claims} ->
        user = %{
          user_id: claims["sub"],
          email: claims["email"],
          username: claims["username"] || claims["email"],
          roles: claims["roles"] || []
        }
        {:ok, user}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  def verify_token(_), do: {:error, :invalid_token}

  @doc """
  Ensures user directories exist for file-based apps.
  Creates both shared and user-specific directories.
  """
  def ensure_user_directories(user_email, base_path \\ nil) do
    base_path = base_path || Path.join([System.user_home(), to_string(get_app_name()) |> String.downcase()])
    
    directories = [
      Path.join([base_path, "shared"]),
      Path.join([base_path, "users", user_email])
    ]
    
    Enum.each(directories, fn dir ->
      case File.mkdir_p(dir) do
        :ok -> :ok
        {:error, reason} ->
          require Logger
          Logger.warning("Failed to create directory #{dir}: #{inspect(reason)}")
      end
    end)
    
    %{
      shared: Path.join([base_path, "shared"]),
      user_root: Path.join([base_path, "users", user_email]),
      accessible_paths: [
        Path.join([base_path, "shared"]),
        Path.join([base_path, "users", user_email])
      ]
    }
  end
end