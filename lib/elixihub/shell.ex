defmodule Elixihub.Shell do
  @moduledoc """
  The Shell context for managing remote IEx sessions.
  """

  @doc """
  Executes code on a remote node with proper error handling and formatting.
  """
  def execute_on_node(node, code, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    
    cond do
      # If this is the current node, execute locally
      node.is_current ->
        try do
          case safe_eval(code) do
            {:ok, result} -> {:ok, result}
            {:error, error} -> {:error, format_eval_error(error)}
          end
        rescue
          error ->
            {:error, "Local execution failed: #{Exception.message(error)}"}
        end
      
      # If it's a remote node, use RPC
      node_connected?(node) ->
        node_name = String.to_atom("#{node.name}@#{node.host}")
        
        try do
          # Use Code.eval_string directly on the remote node instead of our custom function
          task = Task.async(fn ->
            :rpc.call(node_name, Code, :eval_string, [code], timeout)
          end)
          
          case Task.await(task, timeout + 1000) do
            {:badrpc, reason} ->
              {:error, format_rpc_error(reason)}
            
            {result, _bindings} ->
              {:ok, result}
            
            result ->
              {:ok, result}
          end
        rescue
          error ->
            {:error, "Remote execution failed: #{Exception.message(error)}"}
        catch
          :exit, reason ->
            {:error, "Process exited: #{inspect(reason)}"}
          
          :throw, value ->
            {:error, "Thrown: #{inspect(value)}"}
          
          :error, reason ->
            {:error, "Error: #{inspect(reason)}"}
        end
      
      # Node is not connected
      true ->
        {:error, "Node #{node.name}@#{node.host} is not connected"}
    end
  end

  @doc """
  Safely evaluates Elixir code with proper error handling.
  This function runs on the remote node.
  """
  def safe_eval(code) do
    try do
      # Create a clean binding for evaluation
      binding = []
      
      # Evaluate the code
      {result, _new_binding} = Code.eval_string(code, binding)
      
      {:ok, result}
    rescue
      error in [CompileError, SyntaxError, TokenMissingError] ->
        {:error, %{type: :compile_error, message: Exception.message(error)}}
      
      error in [ArithmeticError, ArgumentError, BadArityError, BadBooleanError, 
                CaseClauseError, CondClauseError, FunctionClauseError] ->
        {:error, %{type: :runtime_error, message: Exception.message(error)}}
      
      error ->
        {:error, %{type: :unknown_error, message: Exception.message(error), exception: inspect(error)}}
    catch
      :exit, reason ->
        {:error, %{type: :exit, reason: inspect(reason)}}
      
      :throw, value ->
        {:error, %{type: :throw, value: inspect(value)}}
      
      :error, reason ->
        {:error, %{type: :error, reason: inspect(reason)}}
    end
  end

  @doc """
  Gets information about a remote node.
  """
  def get_node_info(node) do
    cond do
      node.is_current ->
        # Get local info
        info = %{
          node: :erlang.node(),
          applications: Application.started_applications(),
          system_info: %{
            version: System.version(),
            otp_release: System.otp_release(),
            schedulers: :erlang.system_info(:schedulers),
            process_count: :erlang.system_info(:process_count)
          }
        }
        {:ok, info}
      
      node_connected?(node) ->
        node_name = String.to_atom("#{node.name}@#{node.host}")
        
        info = %{
          node: node_name,
          applications: :rpc.call(node_name, Application, :started_applications, []),
          system_info: %{
            version: :rpc.call(node_name, System, :version, []),
            otp_release: :rpc.call(node_name, System, :otp_release, []),
            schedulers: :rpc.call(node_name, :erlang, :system_info, [:schedulers]),
            process_count: :rpc.call(node_name, :erlang, :system_info, [:process_count])
          }
        }
        
        {:ok, info}
      
      true ->
        {:error, "Node not connected"}
    end
  end

  @doc """
  Lists all processes on a remote node.
  """
  def list_remote_processes(node, limit \\ 50) do
    cond do
      node.is_current ->
        # Get local processes
        processes = Process.list()
        |> Enum.take(limit)
        |> Enum.map(fn pid ->
          info = Process.info(pid, [:registered_name, :current_function, :message_queue_len])
          %{
            pid: inspect(pid),
            name: Keyword.get(info, :registered_name),
            current_function: Keyword.get(info, :current_function),
            message_queue_len: Keyword.get(info, :message_queue_len)
          }
        end)
        
        {:ok, processes}
      
      node_connected?(node) ->
        node_name = String.to_atom("#{node.name}@#{node.host}")
        
        processes = :rpc.call(node_name, Process, :list, [])
        |> Enum.take(limit)
        |> Enum.map(fn pid ->
          info = :rpc.call(node_name, Process, :info, [pid, [:registered_name, :current_function, :message_queue_len]])
          %{
            pid: inspect(pid),
            name: Keyword.get(info, :registered_name),
            current_function: Keyword.get(info, :current_function),
            message_queue_len: Keyword.get(info, :message_queue_len)
          }
        end)
        
        {:ok, processes}
      
      true ->
        {:error, "Node not connected"}
    end
  end

  @doc """
  Formats the result of code execution for display.
  """
  def format_result(result) do
    case result do
      {value, _bindings} ->
        # Result from Code.eval_string with bindings
        format_value(value)
      
      value ->
        # Direct result
        format_value(value)
    end
  end

  @doc """
  Validates if Elixir code is syntactically correct without executing it.
  """
  def validate_syntax(code) do
    try do
      Code.string_to_quoted(code)
      :ok
    rescue
      error ->
        {:error, Exception.message(error)}
    end
  end

  # Private functions

  defp node_connected?(node) do
    if node.is_current do
      # Current node is always "connected"
      true
    else
      node_name = String.to_atom("#{node.name}@#{node.host}")
      node_name in :erlang.nodes()
    end
  end

  defp format_value(value) do
    inspect(value, 
      pretty: true, 
      limit: :infinity, 
      width: 80,
      syntax_colors: []
    )
    |> String.split("\n")
  end

  defp format_rpc_error(reason) do
    case reason do
      :nodedown ->
        "Node is down or unreachable"
      
      :timeout ->
        "Operation timed out"
      
      {:EXIT, exit_reason} ->
        "Remote process exited: #{inspect(exit_reason)}"
      
      other ->
        "RPC error: #{inspect(other)}"
    end
  end

  defp format_eval_error(%{type: type, message: message}) do
    case type do
      :compile_error ->
        "** (CompileError) #{message}"
      
      :runtime_error ->
        "** (RuntimeError) #{message}"
      
      :throw ->
        "** (throw) #{message}"
      
      :exit ->
        "** (exit) #{message}"
      
      :error ->
        "** (error) #{message}"
      
      :unknown_error ->
        "** (UnknownError) #{message}"
    end
  end

  defp format_eval_error(error) when is_binary(error) do
    "** Error: #{error}"
  end

  defp format_eval_error(error) do
    "** Error: #{inspect(error)}"
  end
end