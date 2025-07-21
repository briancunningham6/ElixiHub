defmodule Elixihub.Apps do
  @moduledoc """
  The Apps context.
  """

  import Ecto.Query, warn: false
  alias Elixihub.Repo

  alias Elixihub.Apps.App
  alias Elixihub.Apps.AppRole

  @doc """
  Returns the list of apps.

  ## Examples

      iex> list_apps()
      [%App{}, ...]

  """
  def list_apps do
    Repo.all(App) |> Repo.preload(:node)
  end

  @doc """
  Returns the list of active apps.

  ## Examples

      iex> list_active_apps()
      [%App{}, ...]

  """
  def list_active_apps do
    from(a in App, where: a.status == "active")
    |> Repo.all()
  end

  @doc """
  Gets a single app.

  Raises `Ecto.NoResultsError` if the App does not exist.

  ## Examples

      iex> get_app!(123)
      %App{}

      iex> get_app!(456)
      ** (Ecto.NoResultsError)

  """
  def get_app!(id), do: Repo.get!(App, id)

  @doc """
  Gets an app by API key.

  ## Examples

      iex> get_app_by_api_key("valid_key")
      %App{}

      iex> get_app_by_api_key("invalid_key")
      nil

  """
  def get_app_by_api_key(api_key) do
    Repo.get_by(App, api_key: api_key)
  end

  @doc """
  Gets an app by name.

  ## Examples

      iex> get_app_by_name("task_manager")
      %App{}

      iex> get_app_by_name("nonexistent")
      nil

  """
  def get_app_by_name(name) do
    Repo.get_by(App, name: name)
  end

  @doc """
  Creates an app.

  ## Examples

      iex> create_app(%{field: value})
      {:ok, %App{}}

      iex> create_app(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_app(attrs \\ %{}) do
    %App{}
    |> App.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an app.

  ## Examples

      iex> update_app(app, %{field: new_value})
      {:ok, %App{}}

      iex> update_app(app, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_app(%App{} = app, attrs) do
    app
    |> App.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an app.

  ## Examples

      iex> delete_app(app)
      {:ok, %App{}}

      iex> delete_app(app)
      {:error, %Ecto.Changeset{}}

  """
  def delete_app(%App{} = app) do
    Repo.delete(app)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking app changes.

  ## Examples

      iex> change_app(app)
      %Ecto.Changeset{data: %App{}}

  """
  def change_app(%App{} = app, attrs \\ %{}) do
    App.changeset(app, attrs)
  end

  @doc """
  Activates an app.
  """
  def activate_app(%App{} = app) do
    update_app(app, %{status: "active"})
  end

  @doc """
  Deactivates an app.
  """
  def deactivate_app(%App{} = app) do
    update_app(app, %{status: "inactive"})
  end

  # App Role functions

  @doc """
  Returns the list of app roles for a specific app.
  """
  def list_app_roles(app_id) do
    from(ar in AppRole, where: ar.app_id == ^app_id)
    |> Repo.all()
  end

  @doc """
  Gets a single app role.
  """
  def get_app_role!(id), do: Repo.get!(AppRole, id)

  @doc """
  Gets an app role by app and identifier.
  """
  def get_app_role_by_identifier(app_id, identifier) do
    Repo.get_by(AppRole, app_id: app_id, identifier: identifier)
  end

  @doc """
  Creates an app role.
  """
  def create_app_role(attrs \\ %{}) do
    %AppRole{}
    |> AppRole.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an app role.
  """
  def update_app_role(%AppRole{} = app_role, attrs) do
    app_role
    |> AppRole.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an app role.
  """
  def delete_app_role(%AppRole{} = app_role) do
    Repo.delete(app_role)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking app role changes.
  """
  def change_app_role(%AppRole{} = app_role, attrs \\ %{}) do
    AppRole.changeset(app_role, attrs)
  end

  @doc """
  Creates or updates app roles based on role definitions.
  This is called during app installation.
  """
  def sync_app_roles(app_id, role_definitions) when is_list(role_definitions) do
    Repo.transaction(fn ->
      Enum.each(role_definitions, fn role_def ->
        case get_app_role_by_identifier(app_id, role_def.identifier) do
          nil ->
            create_app_role(%{
              app_id: app_id,
              name: role_def.name,
              description: role_def.description,
              identifier: role_def.identifier,
              permissions: role_def.permissions || %{},
              metadata: role_def.metadata || %{}
            })
          
          existing_role ->
            update_app_role(existing_role, %{
              name: role_def.name,
              description: role_def.description,
              permissions: role_def.permissions || %{},
              metadata: role_def.metadata || %{}
            })
        end
      end)
    end)
  end
end