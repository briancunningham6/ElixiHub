defmodule Elixihub.Apps do
  @moduledoc """
  The Apps context.
  """

  import Ecto.Query, warn: false
  alias Elixihub.Repo

  alias Elixihub.Apps.App

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
end