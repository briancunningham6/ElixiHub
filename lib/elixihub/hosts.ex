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
    # Use IP address for connection test
    case try_connection_with_host(host.ip_address, host) do
      {:ok, message} -> 
        {:ok, message}
      {:error, reason} ->
        {:error, reason}
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
  def host_to_ssh_config(%Host{} = host) do
    %{
      host: host.ip_address,
      port: host.ssh_port,
      username: host.ssh_username || "root",  # Default to "root" if nil
      password: host.ssh_password
    }
  end

  @doc """
  Restarts a host via SSH by executing restart commands.
  """
  def restart_host(%Host{} = host) do
    ssh_config = host_to_ssh_config(host)
    
    # Use IP address for restart
    case try_restart_with_host(host.ip_address, ssh_config) do
      {:ok, message} -> 
        {:ok, message}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp try_restart_with_host(hostname, ssh_config) do
    updated_config = Map.put(ssh_config, :host, hostname)
    
    case Elixihub.Deployment.SSHClient.connect(updated_config) do
      {:ok, conn} ->
        try do
          # Try different restart commands based on the system
          restart_commands = [
            "sudo systemctl reboot",  # systemd systems
            "sudo reboot",            # general reboot command
            "sudo shutdown -r now"    # alternative reboot command
          ]
          
          # Execute the first available restart command
          result = Enum.find_value(restart_commands, fn command ->
            case Elixihub.Deployment.SSHClient.execute_command(conn, command, timeout: 10000) do
              {:ok, _output} -> 
                {:ok, "Restart command executed successfully"}
              {:error, reason} -> 
                # Connection lost is expected when rebooting
                if String.contains?(reason, "Connection lost") or String.contains?(reason, "closed") do
                  {:ok, "Restart initiated (connection lost as expected)"}
                else
                  nil  # Try next command
                end
            end
          end)
          
          case result do
            {:ok, message} -> {:ok, message}
            nil -> {:error, "All restart commands failed - insufficient privileges or unsupported system"}
          end
        after
          Elixihub.Deployment.SSHClient.disconnect(conn)
        end
      
      {:error, reason} ->
        cond do
          reason =~ "nxdomain" ->
            {:error, "DNS resolution failed"}
          reason =~ "authentication" or reason =~ "auth" ->
            {:error, "Authentication failed - check SSH credentials"}
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
end