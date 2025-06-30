defmodule Elixihub.Authorization do
  @moduledoc """
  The Authorization context.
  """

  import Ecto.Query, warn: false
  alias Elixihub.Repo

  alias Elixihub.Authorization.{Role, Permission}
  alias Elixihub.Accounts.User

  @doc """
  Returns the list of roles.

  ## Examples

      iex> list_roles()
      [%Role{}, ...]

  """
  def list_roles do
    Repo.all(Role)
  end

  @doc """
  Gets a single role.

  Raises `Ecto.NoResultsError` if the Role does not exist.

  ## Examples

      iex> get_role!(123)
      %Role{}

      iex> get_role!(456)
      ** (Ecto.NoResultsError)

  """
  def get_role!(id), do: Repo.get!(Role, id)

  @doc """
  Creates a role.

  ## Examples

      iex> create_role(%{field: value})
      {:ok, %Role{}}

      iex> create_role(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_role(attrs \\ %{}) do
    %Role{}
    |> Role.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a role.

  ## Examples

      iex> update_role(role, %{field: new_value})
      {:ok, %Role{}}

      iex> update_role(role, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_role(%Role{} = role, attrs) do
    role
    |> Role.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a role.

  ## Examples

      iex> delete_role(role)
      {:ok, %Role{}}

      iex> delete_role(role)
      {:error, %Ecto.Changeset{}}

  """
  def delete_role(%Role{} = role) do
    Repo.delete(role)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking role changes.

  ## Examples

      iex> change_role(role)
      %Ecto.Changeset{data: %Role{}}

  """
  def change_role(%Role{} = role, attrs \\ %{}) do
    Role.changeset(role, attrs)
  end

  @doc """
  Returns the list of permissions.

  ## Examples

      iex> list_permissions()
      [%Permission{}, ...]

  """
  def list_permissions do
    Repo.all(Permission)
  end

  @doc """
  Gets a single permission.

  Raises `Ecto.NoResultsError` if the Permission does not exist.

  ## Examples

      iex> get_permission!(123)
      %Permission{}

      iex> get_permission!(456)
      ** (Ecto.NoResultsError)

  """
  def get_permission!(id), do: Repo.get!(Permission, id)

  @doc """
  Creates a permission.

  ## Examples

      iex> create_permission(%{field: value})
      {:ok, %Permission{}}

      iex> create_permission(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_permission(attrs \\ %{}) do
    %Permission{}
    |> Permission.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a permission.

  ## Examples

      iex> update_permission(permission, %{field: new_value})
      {:ok, %Permission{}}

      iex> update_permission(permission, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_permission(%Permission{} = permission, attrs) do
    permission
    |> Permission.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a permission.

  ## Examples

      iex> delete_permission(permission)
      {:ok, %Permission{}}

      iex> delete_permission(permission)
      {:error, %Ecto.Changeset{}}

  """
  def delete_permission(%Permission{} = permission) do
    Repo.delete(permission)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking permission changes.

  ## Examples

      iex> change_permission(permission)
      %Ecto.Changeset{data: %Permission{}}

  """
  def change_permission(%Permission{} = permission, attrs \\ %{}) do
    Permission.changeset(permission, attrs)
  end

  @doc """
  Assigns a role to a user.
  """
  def assign_role_to_user(user, role) do
    alias Elixihub.Authorization.UserRole
    
    # Check if user already has this role
    existing = Repo.get_by(UserRole, user_id: user.id, role_id: role.id)
    
    if existing do
      {:ok, user}
    else
      %UserRole{}
      |> UserRole.changeset(%{user_id: user.id, role_id: role.id})
      |> Repo.insert()
      |> case do
        {:ok, _user_role} -> {:ok, user}
        error -> error
      end
    end
  end

  @doc """
  Removes a role from a user.
  """
  def remove_role_from_user(user, role) do
    user = Repo.preload(user, :roles)
    updated_roles = Enum.reject(user.roles, &(&1.id == role.id))
    
    user
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:roles, updated_roles)
    |> Repo.update()
  end

  @doc """
  Assigns a permission to a role.
  """
  def assign_permission_to_role(role, permission) do
    role
    |> Repo.preload(:permissions)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:permissions, [permission | role.permissions])
    |> Repo.update()
  end

  @doc """
  Removes a permission from a role.
  """
  def remove_permission_from_role(role, permission) do
    role = Repo.preload(role, :permissions)
    updated_permissions = Enum.reject(role.permissions, &(&1.id == permission.id))
    
    role
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:permissions, updated_permissions)
    |> Repo.update()
  end

  @doc """
  Gets all permissions for a user (through their roles).
  """
  def get_user_permissions(%User{} = user) do
    user = Repo.preload(user, roles: :permissions)
    
    user.roles
    |> Enum.flat_map(& &1.permissions)
    |> Enum.uniq_by(& &1.id)
  end

  @doc """
  Checks if a user has a specific permission.
  """
  def user_has_permission?(%User{} = user, permission_name) do
    user
    |> get_user_permissions()
    |> Enum.any?(&(&1.name == permission_name))
  end

  # App Role functions

  @doc """
  Assigns an app role to a user.
  """
  def assign_app_role_to_user(user, app_role) do
    alias Elixihub.Authorization.UserRole
    
    # Check if user already has this app role
    existing = Repo.get_by(UserRole, user_id: user.id, app_role_id: app_role.id)
    
    if existing do
      {:ok, user}
    else
      %UserRole{}
      |> UserRole.changeset(%{user_id: user.id, app_role_id: app_role.id})
      |> Repo.insert()
      |> case do
        {:ok, _user_role} -> {:ok, user}
        error -> error
      end
    end
  end

  @doc """
  Removes an app role from a user.
  """
  def remove_app_role_from_user(user, app_role) do
    alias Elixihub.Authorization.UserRole
    
    case Repo.get_by(UserRole, user_id: user.id, app_role_id: app_role.id) do
      nil -> {:ok, user}
      user_role -> 
        case Repo.delete(user_role) do
          {:ok, _} -> {:ok, user}
          error -> error
        end
    end
  end

  @doc """
  Gets all app roles for a user.
  """
  def get_user_app_roles(%User{} = user) do
    alias Elixihub.Authorization.UserRole
    alias Elixihub.Apps.AppRole
    
    from(ur in UserRole,
      join: ar in AppRole, on: ur.app_role_id == ar.id,
      where: ur.user_id == ^user.id and not is_nil(ur.app_role_id),
      select: ar,
      preload: [:app]
    )
    |> Repo.all()
  end

  @doc """
  Checks if a user has a specific app role.
  """
  def user_has_app_role?(%User{} = user, app_role_identifier, app_id) do
    alias Elixihub.Authorization.UserRole
    alias Elixihub.Apps.AppRole
    
    query = from ur in UserRole,
      join: ar in AppRole, on: ur.app_role_id == ar.id,
      where: ur.user_id == ^user.id and 
             ar.identifier == ^app_role_identifier and 
             ar.app_id == ^app_id
    
    Repo.exists?(query)
  end
end