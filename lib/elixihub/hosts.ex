defmodule Elixihub.Hosts do
  @moduledoc """
  The Hosts context for managing deployment hosts.
  """

  import Ecto.Query, warn: false
  alias Elixihub.Repo

  alias Elixihub.Hosts.Host

  @doc """
  Returns the list of hosts.
  """
  def list_hosts do
    Repo.all(Host)
  end

  @doc """
  Gets a single host.

  Raises `Ecto.NoResultsError` if the Host does not exist.
  """
  def get_host!(id), do: Repo.get!(Host, id)

  @doc """
  Creates a host.
  """
  def create_host(attrs \\ %{}) do
    %Host{}
    |> Host.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a host.
  """
  def update_host(%Host{} = host, attrs) do
    host
    |> Host.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a host.
  """
  def delete_host(%Host{} = host) do
    Repo.delete(host)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking host changes.
  """
  def change_host(%Host{} = host, attrs \\ %{}) do
    Host.changeset(host, attrs)
  end

  @doc """
  Gets host options for dropdowns.
  """
  def get_host_options do
    list_hosts()
    |> Enum.map(fn host ->
      label = "#{host.name} (#{host.ip_address})"
      {label, host.id}
    end)
  end

  @doc """
  Tests SSH connectivity to a host.
  """
  def test_connection(%Host{} = host) do
    ssh_config = %{
      host: host.ssh_hostname,
      port: host.ssh_port,
      username: "test", # This would need actual username
      password: host.ssh_password
    }

    case Elixihub.Deployment.SSHClient.connect(ssh_config) do
      {:ok, conn} ->
        Elixihub.Deployment.SSHClient.disconnect(conn)
        {:ok, "Connection successful"}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Converts a host to SSH configuration map.
  """
  def host_to_ssh_config(%Host{} = host, username) do
    %{
      host: host.ssh_hostname,
      port: host.ssh_port,
      username: username,
      password: host.ssh_password
    }
  end
end