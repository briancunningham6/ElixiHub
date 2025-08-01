defmodule TaskManagerWeb.MCPController do
  use TaskManagerWeb, :controller
  require Logger

  alias TaskManager.Tasks

  def handle_request(conn, params) do
    # Get parsed params from auth plug or from normal Phoenix params
    parsed_params = conn.assigns[:parsed_params] || params
    
    {method, request_params, id} = case parsed_params do
      %{"method" => method, "params" => request_params, "id" => id} ->
        {method, request_params, id}
      %{"method" => method, "id" => id} ->
        {method, %{}, id}
      %{"method" => method} ->
        {method, %{}, nil}
      _ ->
        {nil, %{}, nil}
    end
    
    if method do
      user_id = get_user_id(conn)
      handle_method(conn, method, request_params, user_id, id)
    else
      json(conn, %{
        jsonrpc: "2.0",
        error: %{code: -32600, message: "Invalid Request"},
        id: nil
      })
    end
  end

  defp handle_method(conn, method, params, user_id, id) do
    
    case method do
      "tools/list" -> handle_tools_list(conn, params, user_id, id)
      "list_tasks" -> handle_list_tasks(conn, params, user_id, id)
      "list_private_tasks" -> handle_list_private_tasks(conn, params, user_id, id)
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

  defp handle_tools_list(conn, _params, _user_id, id) do
    # Note: tools/list doesn't need user authentication as it just returns available tools
    # Return the list of available MCP tools as defined in mcp.json
    tools = [
      %{
        name: "list_tasks",
        description: "List tasks for the current user",
        inputSchema: %{
          type: "object",
          properties: %{
            status: %{
              type: "string",
              enum: ["pending", "in_progress", "completed", "cancelled"],
              description: "Filter tasks by status"
            }
          }
        }
      },
      %{
        name: "list_private_tasks", 
        description: "List private tasks for the current user",
        inputSchema: %{
          type: "object",
          properties: %{
            status: %{
              type: "string",
              enum: ["pending", "in_progress", "completed", "cancelled"], 
              description: "Filter private tasks by status"
            }
          }
        }
      },
      %{
        name: "create_task",
        description: "Create a new task", 
        inputSchema: %{
          type: "object",
          properties: %{
            title: %{type: "string", description: "Task title"},
            description: %{type: "string", description: "Task description"},
            priority: %{
              type: "string", 
              enum: ["low", "medium", "high", "urgent"],
              description: "Task priority"
            },
            due_date: %{
              type: "string",
              format: "date-time", 
              description: "Due date in ISO 8601 format"
            },
            assignee_id: %{type: "string", description: "ID of the user to assign the task to"},
            tags: %{
              type: "array",
              items: %{type: "string"},
              description: "Task tags" 
            }
          },
          required: ["title"]
        }
      },
      %{
        name: "update_task",
        description: "Update an existing task",
        inputSchema: %{
          type: "object", 
          properties: %{
            task_id: %{type: "string", description: "ID of the task to update"},
            title: %{type: "string", description: "Task title"},
            description: %{type: "string", description: "Task description"},
            status: %{
              type: "string",
              enum: ["pending", "in_progress", "completed", "cancelled"],
              description: "Task status"
            },
            priority: %{
              type: "string",
              enum: ["low", "medium", "high", "urgent"], 
              description: "Task priority"
            },
            due_date: %{
              type: "string",
              format: "date-time",
              description: "Due date in ISO 8601 format"
            },
            assignee_id: %{type: "string", description: "ID of the user to assign the task to"},
            tags: %{
              type: "array", 
              items: %{type: "string"},
              description: "Task tags"
            }
          },
          required: ["task_id"]
        }
      },
      %{
        name: "delete_task",
        description: "Delete a task",
        inputSchema: %{
          type: "object",
          properties: %{
            task_id: %{type: "string", description: "ID of the task to delete"}
          },
          required: ["task_id"]
        }
      },
      %{
        name: "complete_task",
        description: "Mark a task as completed",
        inputSchema: %{
          type: "object", 
          properties: %{
            task_id: %{type: "string", description: "ID of the task to complete"}
          },
          required: ["task_id"]
        }
      },
      %{
        name: "get_task_stats",
        description: "Get task statistics",
        inputSchema: %{type: "object", properties: %{}}
      }
    ]

    json(conn, %{
      jsonrpc: "2.0",
      result: %{tools: tools}, 
      id: id
    })
  end

  defp handle_list_tasks(conn, params, user_id, id) do
    status = params["status"]
    
    # Add debugging
    Logger.info("list_tasks called with user_id: #{inspect(user_id)}, status: #{inspect(status)}")
    Logger.info("current_user from conn: #{inspect(conn.assigns[:current_user])}")
    
    tasks = case status do
      nil -> Tasks.list_tasks_by_user(user_id)
      status -> Tasks.list_tasks_by_user(user_id) |> Enum.filter(&(&1.status == status))
    end

    Logger.info("Found #{length(tasks)} tasks for user #{user_id}")
    Enum.each(tasks, fn task ->
      Logger.info("- Task: #{task.title} (ID: #{task.id}, Status: #{task.status})")
    end)

    json(conn, %{
      jsonrpc: "2.0",
      result: %{
        tasks: Enum.map(tasks, &task_to_json/1),
        count: length(tasks),
        debug_user_id: user_id
      },
      id: id
    })
  end

  defp handle_list_private_tasks(conn, params, user_id, id) do
    status = params["status"]
    
    # Add debugging
    Logger.info("list_private_tasks called with user_id: #{inspect(user_id)}, status: #{inspect(status)}")
    
    # Get all tasks for the user and filter for private tasks
    all_user_tasks = Tasks.list_tasks_by_user(user_id)
    private_tasks = Enum.filter(all_user_tasks, &(&1.private == true))
    
    Logger.info("Found #{length(all_user_tasks)} total tasks, #{length(private_tasks)} private tasks for user #{user_id}")
    
    # Apply status filter if provided
    filtered_tasks = case status do
      nil -> private_tasks
      status -> Enum.filter(private_tasks, &(&1.status == status))
    end

    json(conn, %{
      jsonrpc: "2.0",
      result: %{
        tasks: Enum.map(filtered_tasks, &task_to_json/1),
        count: length(filtered_tasks),
        message: "Showing #{length(filtered_tasks)} private task(s)",
        debug_user_id: user_id
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
      private: task.private,
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
    current_user = conn.assigns[:current_user]
    Logger.info("get_user_id - current_user: #{inspect(current_user)}")
    Logger.info("get_user_id - all conn assigns: #{inspect(Map.keys(conn.assigns))}")
    
    case current_user do
      %{"sub" => user_id} -> 
        Logger.info("get_user_id - extracted user_id from sub: #{inspect(user_id)}")
        user_id
      %{id: user_id} -> 
        Logger.info("get_user_id - extracted user_id from id: #{inspect(user_id)}")
        user_id
      _ -> 
        Logger.warning("get_user_id - no user_id found, returning nil")
        nil
    end
  end
end