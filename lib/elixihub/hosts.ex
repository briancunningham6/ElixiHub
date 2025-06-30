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
    # Try with ssh_hostname first
    case try_connection_with_host(host.ssh_hostname, host) do
      {:ok, message} -> 
        {:ok, message}
      {:error, reason} ->
        # If hostname resolution fails, try with IP address
        if String.contains?(reason, "nxdomain") or String.contains?(reason, "DNS resolution failed") do
          case try_connection_with_host(host.ip_address, host) do
            {:ok, message} -> {:ok, "#{message} (used IP address as fallback)"}
            {:error, ip_reason} -> {:error, "Hostname failed: #{reason}, IP failed: #{ip_reason}"}
          end
        else
          {:error, reason}
        end
    end
  end

  defp try_connection_with_host(hostname, %Host{} = host) do
    # Use a minimal SSH config just to test connectivity
    ssh_config = %{
      host: hostname,
      port: host.ssh_port,
      username: "test", # Dummy username for connection test
      timeout: 5000 # Short timeout for connection test
    }

    case Elixihub.Deployment.SSHClient.connect(ssh_config) do
      {:ok, conn} ->
        Elixihub.Deployment.SSHClient.disconnect(conn)
        {:ok, "SSH port is reachable"}
      
      {:error, reason} ->
        cond do
          reason =~ "nxdomain" ->
            {:error, "DNS resolution failed"}
          reason =~ "authentication" or reason =~ "auth" ->
            {:ok, "SSH port is reachable (authentication not tested)"}
          reason =~ "connection refused" or reason =~ "econnrefused" ->
            {:error, "Connection refused - SSH service may not be running"}
          reason =~ "timeout" or reason =~ "etimedout" ->
            {:error, "Connection timeout - host may be unreachable"}
          reason =~ "host unreachable" or reason =~ "ehostunreach" ->
            {:error, "Host unreachable"}
          reason =~ "network unreachable" or reason =~ "enetunreach" ->
            {:error, "Network unreachable"}
          true ->
            {:error, reason}
        end
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