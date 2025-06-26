defmodule ElixihubWeb.Api.AppController do
  use ElixihubWeb, :controller

  alias Elixihub.Apps
  alias Elixihub.Authorization.Policy
  alias Elixihub.Guardian

  action_fallback ElixihubWeb.FallbackController

  def index(conn, _params) do
    current_user = Guardian.Plug.current_resource(conn)
    
    with :ok <- Bodyguard.permit(Policy, :list_apps, current_user) do
      apps = Apps.list_apps()
      
      apps_data = 
        Enum.map(apps, fn app ->
          %{
            id: app.id,
            name: app.name,
            description: app.description,
            url: app.url,
            status: app.status,
            api_key: app.api_key,
            inserted_at: app.inserted_at,
            updated_at: app.updated_at
          }
        end)
      
      conn
      |> put_status(:ok)
      |> json(%{apps: apps_data})
    end
  end

  def create(conn, %{"app" => app_params}) do
    current_user = Guardian.Plug.current_resource(conn)
    
    with :ok <- Bodyguard.permit(Policy, :create_app, current_user) do
      case Apps.create_app(app_params) do
        {:ok, app} ->
          conn
          |> put_status(:created)
          |> json(%{
            app: %{
              id: app.id,
              name: app.name,
              description: app.description,
              url: app.url,
              status: app.status,
              api_key: app.api_key
            }
          })

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: transform_errors(changeset)})
      end
    end
  end

  def show(conn, %{"id" => id}) do
    current_user = Guardian.Plug.current_resource(conn)
    app = Apps.get_app!(id)
    
    with :ok <- Bodyguard.permit(Policy, :list_apps, current_user) do
      conn
      |> put_status(:ok)
      |> json(%{
        app: %{
          id: app.id,
          name: app.name,
          description: app.description,
          url: app.url,
          status: app.status,
          api_key: app.api_key,
          inserted_at: app.inserted_at,
          updated_at: app.updated_at
        }
      })
    end
  end

  def update(conn, %{"id" => id, "app" => app_params}) do
    current_user = Guardian.Plug.current_resource(conn)
    app = Apps.get_app!(id)
    
    with :ok <- Bodyguard.permit(Policy, :update_app, current_user, app) do
      case Apps.update_app(app, app_params) do
        {:ok, app} ->
          conn
          |> put_status(:ok)
          |> json(%{
            app: %{
              id: app.id,
              name: app.name,
              description: app.description,
              url: app.url,
              status: app.status,
              api_key: app.api_key
            }
          })

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: transform_errors(changeset)})
      end
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = Guardian.Plug.current_resource(conn)
    app = Apps.get_app!(id)
    
    with :ok <- Bodyguard.permit(Policy, :delete_app, current_user, app) do
      case Apps.delete_app(app) do
        {:ok, _app} ->
          conn
          |> put_status(:ok)
          |> json(%{message: "App deleted successfully"})

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: transform_errors(changeset)})
      end
    end
  end

  defp transform_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end