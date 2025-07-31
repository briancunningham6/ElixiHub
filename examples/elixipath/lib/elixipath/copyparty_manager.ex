defmodule ElixiPath.CopypartyManager do
  @moduledoc """
  Manages the Copyparty Python subprocess for file server functionality.
  """
  use GenServer
  require Logger

  @copyparty_port 8090
  @base_path Path.join([System.user_home(), "elixipath"])

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_state) do
    Logger.info("Starting Copyparty Manager...")
    
    # Ensure directory structure exists
    ensure_directory_structure()
    
    # Check if copyparty is available before starting
    case check_copyparty_available() do
      true ->
        # Start copyparty subprocess
        port = start_copyparty()
        {:ok, %{port: port, status: :starting}}
      
      false ->
        Logger.warning("Copyparty not available. Install with: pip install copyparty")
        {:ok, %{port: nil, status: :unavailable}}
    end
  end

  def handle_info({port, {:data, data}}, %{port: port} = state) when port != nil do
    Logger.info("Copyparty output: #{data}")
    {:noreply, state}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) when port != nil do
    Logger.error("Copyparty exited with status: #{status}")
    # Only restart if copyparty is available
    case check_copyparty_available() do
      true ->
        new_port = start_copyparty()
        {:noreply, %{state | port: new_port}}
      false ->
        {:noreply, %{state | port: nil, status: :unavailable}}
    end
  end

  def handle_info({:EXIT, port, reason}, %{port: port} = state) when port != nil do
    Logger.error("Copyparty process died: #{inspect(reason)}")
    # Only restart if copyparty is available
    case check_copyparty_available() do
      true ->
        new_port = start_copyparty()
        {:noreply, %{state | port: new_port}}
      false ->
        {:noreply, %{state | port: nil, status: :unavailable}}
    end
  end

  def handle_info(_msg, state) do
    # Ignore unknown messages
    {:noreply, state}
  end

  def terminate(_reason, %{port: port}) do
    if port && Port.info(port) do
      Port.close(port)
    end
    :ok
  end

  defp check_copyparty_available do
    case System.cmd("python3", ["-m", "copyparty", "--version"], stderr_to_stdout: true) do
      {_output, 0} -> true
      _ -> 
        Logger.warning("copyparty not available - check installation")
        false
    end
  rescue
    _ -> 
      Logger.warning("Python3 or copyparty not available")
      false
  end

  defp ensure_directory_structure do
    # Create base directories
    File.mkdir_p!("#{@base_path}/shared")
    File.mkdir_p!("#{@base_path}/users")
    
    Logger.info("Created directory structure at #{@base_path}")
  end

  defp start_copyparty do
    Logger.info("Starting Copyparty on port #{@copyparty_port}")
    
    args = [
      "-m", "copyparty",
      "--port", "#{@copyparty_port}",
      "--auth-cgi", auth_script_path(),
      "--no-robots",
      "--css", "",
      "--js", "",
      @base_path
    ]

    port = Port.open({:spawn_executable, System.find_executable("python3")}, [
      :binary,
      :exit_status,
      args: args,
      cd: System.tmp_dir()
    ])

    Process.link(port)
    Logger.info("Copyparty started with port #{inspect(port)}")
    port
  end

  defp auth_script_path do
    # Create auth script that validates ElixiHub tokens
    script_path = Path.join(System.tmp_dir(), "elixipath_auth.py")
    
    auth_script_content = """
#!/usr/bin/env python3
import os
import sys
import json
import urllib.request
import urllib.parse

def main():
    # Get auth token from environment (passed by copyparty)
    token = os.environ.get('HTTP_AUTHORIZATION', '').replace('Bearer ', '')
    
    if not token:
        print("Status: 401 Unauthorized")
        print("Content-Type: text/plain")
        print()
        print("No token provided")
        sys.exit(1)
    
    # Validate token with ElixiHub
    try:
        req = urllib.request.Request(
            'http://localhost:4005/api/auth/token',
            headers={'Authorization': f'Bearer {token}'}
        )
        response = urllib.request.urlopen(req)
        user_data = json.loads(response.read().decode())
        
        # Return user info for copyparty
        print("Status: 200 OK")
        print("Content-Type: application/json")
        print()
        print(json.dumps({
            "user": user_data.get("email", "unknown"),
            "groups": ["authenticated"]
        }))
        
    except Exception as e:
        print("Status: 401 Unauthorized")
        print("Content-Type: text/plain")
        print()
        print(f"Authentication failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
"""

    File.write!(script_path, auth_script_content)
    File.chmod!(script_path, 0o755)
    script_path
  end

  # Public API functions
  def get_copyparty_url do
    "http://localhost:#{@copyparty_port}"
  end

  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  def handle_call(:get_status, _from, state) do
    {:reply, state, state}
  end
end