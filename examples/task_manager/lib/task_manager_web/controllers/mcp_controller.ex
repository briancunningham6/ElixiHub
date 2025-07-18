defmodule TaskManagerWeb.MCPController do
  use TaskManagerWeb, :controller

  alias TaskManager.Tasks

  def handle_request(conn, %{"method" => method, "params" => params, "id" => id}) do
    user_id = get_user_id(conn)
    
    case method do
      "list_tasks" -> handle_list_tasks(conn, params, user_id, id)
      "create_task" -> handle_create_task(conn, params, user_id, id)
      "update_task" -> handle_update_task(conn, params, user_id, id)
      "delete_task" -> handle_delete_task(conn, params, user_id, id)
      "complete_task" -> handle_complete_task(conn, params, user_id, id)
      "get_task_stats" -> handle_get_task_stats(conn, params, user_id, id)
      _ -> 
        json(conn, %{
          jsonrpc: "2.0",
          error: %{code: -32601, message: "Method not found"},
          id: id
        })
    end
  end

  def handle_request(conn, _params) do
    json(conn, %{
      jsonrpc: "2.0",
      error: %{code: -32600, message: "Invalid Request"},
      id: nil
    })
  end

  defp handle_list_tasks(conn, params, user_id, id) do
    status = params["status"]
    
    tasks = case status do
      nil -> Tasks.list_tasks_by_user(user_id)
      status -> Tasks.list_tasks_by_user(user_id) |> Enum.filter(&(&1.status == status))
    end

    json(conn, %{
      jsonrpc: "2.0",
      result: %{
        tasks: Enum.map(tasks, &task_to_json/1),
        count: length(tasks)
      },
      id: id
    })
  end

  defp handle_create_task(conn, params, user_id, id) do
    task_params = Map.put(params, "user_id", user_id)
    
    case Tasks.create_task(task_params) do
      {:ok, task} ->
        json(conn, %{
          jsonrpc: "2.0",
          result: %{
            task: task_to_json(task),
            message: "Task created successfully"
          },
          id: id
        })
      {:error, changeset} ->
        json(conn, %{
          jsonrpc: "2.0",
          error: %{
            code: -32602,
            message: "Invalid params",
            data: changeset_errors(changeset)
          },
          id: id
        })
    end
  end

  defp handle_update_task(conn, params, user_id, id) do
    task_id = params["task_id"]
    task_updates = Map.drop(params, ["task_id"])
    
    case Tasks.get_task!(task_id) do
      task when task.user_id == user_id ->
        case Tasks.update_task(task, task_updates) do
          {:ok, updated_task} ->
            json(conn, %{
              jsonrpc: "2.0",
              result: %{
                task: task_to_json(updated_task),
                message: "Task updated successfully"
              },
              id: id
            })
          {:error, changeset} ->
            json(conn, %{
              jsonrpc: "2.0",
              error: %{
                code: -32602,
                message: "Invalid params",
                data: changeset_errors(changeset)
              },
              id: id
            })
        end
      _ ->
        json(conn, %{
          jsonrpc: "2.0",
          error: %{code: -32603, message: "Access denied"},
          id: id
        })
    end
  end

  defp handle_delete_task(conn, params, user_id, id) do
    task_id = params["task_id"]
    
    case Tasks.get_task!(task_id) do
      task when task.user_id == user_id ->
        case Tasks.delete_task(task) do
          {:ok, _} ->
            json(conn, %{
              jsonrpc: "2.0",
              result: %{message: "Task deleted successfully"},
              id: id
            })
          {:error, _} ->
            json(conn, %{
              jsonrpc: "2.0",
              error: %{code: -32603, message: "Internal error"},
              id: id
            })
        end
      _ ->
        json(conn, %{
          jsonrpc: "2.0",
          error: %{code: -32603, message: "Access denied"},
          id: id
        })
    end
  end

  defp handle_complete_task(conn, params, user_id, id) do
    task_id = params["task_id"]
    
    case Tasks.get_task!(task_id) do
      task when task.user_id == user_id ->
        case Tasks.complete_task(task) do
          {:ok, completed_task} ->
            json(conn, %{
              jsonrpc: "2.0",
              result: %{
                task: task_to_json(completed_task),
                message: "Task completed successfully"
              },
              id: id
            })
          {:error, changeset} ->
            json(conn, %{
              jsonrpc: "2.0",
              error: %{
                code: -32602,
                message: "Invalid params",
                data: changeset_errors(changeset)
              },
              id: id
            })
        end
      _ ->
        json(conn, %{
          jsonrpc: "2.0",
          error: %{code: -32603, message: "Access denied"},
          id: id
        })
    end
  end

  defp handle_get_task_stats(conn, _params, _user_id, id) do
    stats = Tasks.get_task_stats()
    
    json(conn, %{
      jsonrpc: "2.0",
      result: stats,
      id: id
    })
  end

  defp task_to_json(task) do
    %{
      id: task.id,
      title: task.title,
      description: task.description,
      status: task.status,
      priority: task.priority,
      user_id: task.user_id,
      assignee_id: task.assignee_id,
      due_date: task.due_date,
      completed_at: task.completed_at,
      tags: task.tags,
      inserted_at: task.inserted_at,
      updated_at: task.updated_at
    }
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp get_user_id(conn) do
    conn.assigns.current_user["sub"]
  end
end