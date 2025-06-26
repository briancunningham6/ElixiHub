defmodule Elixihub.Authorization.Policy do
  @moduledoc """
  Authorization policies using Bodyguard.
  """

  @behaviour Bodyguard.Policy

  alias Elixihub.Accounts.User
  alias Elixihub.Authorization
  alias Elixihub.Authorization.{Role, Permission}

  # User management policies
  def authorize(:list_users, %User{} = user, _params) do
    user_has_permission?(user, "admin:access")
  end

  def authorize(:create_user, %User{} = user, _params) do
    user_has_permission?(user, "admin:access")
  end

  def authorize(:update_user, %User{} = user, target_user) do
    user.id == target_user.id or user_has_permission?(user, "admin:access")
  end

  def authorize(:delete_user, %User{} = user, _target_user) do
    user_has_permission?(user, "admin:access")
  end

  # Role management policies
  def authorize(:list_roles, %User{} = user, _params) do
    user_has_permission?(user, "admin:access")
  end

  def authorize(:create_role, %User{} = user, _params) do
    user_has_permission?(user, "admin:access")
  end

  def authorize(:update_role, %User{} = user, _role) do
    user_has_permission?(user, "admin:access")
  end

  def authorize(:delete_role, %User{} = user, _role) do
    user_has_permission?(user, "admin:access")
  end

  # Permission management policies
  def authorize(:list_permissions, %User{} = user, _params) do
    user_has_permission?(user, "admin:access")
  end

  def authorize(:create_permission, %User{} = user, _params) do
    user_has_permission?(user, "admin:access")
  end

  def authorize(:update_permission, %User{} = user, _permission) do
    user_has_permission?(user, "admin:access")
  end

  def authorize(:delete_permission, %User{} = user, _permission) do
    user_has_permission?(user, "admin:access")
  end

  # App management policies
  def authorize(:list_apps, %User{} = user, _params) do
    user_has_permission?(user, "app:read")
  end

  def authorize(:create_app, %User{} = user, _params) do
    user_has_permission?(user, "app:write")
  end

  def authorize(:update_app, %User{} = user, _app) do
    user_has_permission?(user, "app:write")
  end

  def authorize(:delete_app, %User{} = user, _app) do
    user_has_permission?(user, "app:write")
  end

  # Default deny
  def authorize(_action, _user, _params), do: false

  defp user_has_permission?(user, permission_name) do
    Authorization.user_has_permission?(user, permission_name)
  end
end