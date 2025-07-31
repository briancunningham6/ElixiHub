defmodule ElixiPathWeb.MCPController do
  use ElixiPathWeb, :controller
  require Logger

  alias ElixiPath.FileOperations

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
      user_info = get_user_info(conn)
      handle_method(conn, method, request_params, user_info, id)
    else
      json(conn, %{
        jsonrpc: "2.0",
        error: %{code: -32600, message: "Invalid Request"},
        id: nil
      })
    end
  end

  defp handle_method(conn, method, params, user_info, id) do
    Logger.info("MCP method: #{method} for user: #{inspect(user_info[:email])}")
    
    case method do
      "tools/list" -> handle_tools_list(conn, params, user_info, id)
      "list_files" -> handle_list_files(conn, params, user_info, id)
      "upload_file" -> handle_upload_file(conn, params, user_info, id)
      "delete_file" -> handle_delete_file(conn, params, user_info, id)
      "get_file_info" -> handle_get_file_info(conn, params, user_info, id)
      "create_directory" -> handle_create_directory(conn, params, user_info, id)
      "get_storage_usage" -> handle_get_storage_usage(conn, params, user_info, id)
      _ -> 
        json(conn, %{
          jsonrpc: "2.0",
          error: %{code: -32601, message: "Method not found"},
          id: id
        })
    end
  end

  defp handle_tools_list(conn, _params, _user_info, id) do
    # Return the list of available MCP tools
    tools = [
      %{
        name: "list_files",
        description: "List files and directories for the current user",
        inputSchema: %{
          type: "object",
          properties: %{
            path: %{
              type: "string",
              description: "Directory path to list (relative to user's accessible directories)"
            },
            app_name: %{
              type: "string",
              description: "Filter by application name (optional)"
            }
          }
        }
      },
      %{
        name: "upload_file",
        description: "Upload a file to user's directory",
        inputSchema: %{
          type: "object",
          properties: %{
            path: %{type: "string", description: "Target file path"},
            content: %{type: "string", description: "Base64 encoded file content"},
            app_name: %{type: "string", description: "Application name"}
          },
          required: ["path", "content", "app_name"]
        }
      },
      %{
        name: "delete_file",
        description: "Delete a file or directory",
        inputSchema: %{
          type: "object",
          properties: %{
            path: %{type: "string", description: "File or directory path to delete"}
          },
          required: ["path"]
        }
      },
      %{
        name: "get_file_info",
        description: "Get information about a file or directory",
        inputSchema: %{
          type: "object",
          properties: %{
            path: %{type: "string", description: "File or directory path"}
          },
          required: ["path"]
        }
      },
      %{
        name: "create_directory",
        description: "Create a new directory",
        inputSchema: %{
          type: "object",
          properties: %{
            path: %{type: "string", description: "Directory path to create"},
            app_name: %{type: "string", description: "Application name"}
          },
          required: ["path", "app_name"]
        }
      },
      %{
        name: "get_storage_usage",
        description: "Get storage usage statistics for the user",
        inputSchema: %{
          type: "object",
          properties: %{}
        }
      }
    ]

    json(conn, %{
      jsonrpc: "2.0",
      result: %{tools: tools}, 
      id: id
    })
  end

  defp handle_list_files(conn, params, user_info, id) do
    path = params["path"] || ""
    app_name = params["app_name"]
    
    case FileOperations.list_files(user_info[:email], path, app_name) do
      {:ok, files} ->
        json(conn, %{
          jsonrpc: "2.0",
          result: %{
            files: files,
            count: length(files)
          },
          id: id
        })
      
      {:error, reason} ->
        json(conn, %{
          jsonrpc: "2.0",
          error: %{code: -32603, message: "Failed to list files: #{reason}"},
          id: id
        })
    end
  end

  defp handle_upload_file(conn, params, user_info, id) do
    path = params["path"]
    content = params["content"]
    app_name = params["app_name"]
    
    case FileOperations.upload_file(user_info[:email], path, content, app_name) do
      {:ok, file_info} ->
        json(conn, %{
          jsonrpc: "2.0",
          result: %{
            message: "File uploaded successfully",
            file: file_info
          },
          id: id
        })
      
      {:error, reason} ->
        json(conn, %{
          jsonrpc: "2.0",
          error: %{code: -32603, message: "Failed to upload file: #{reason}"},
          id: id
        })
    end
  end

  defp handle_delete_file(conn, params, user_info, id) do
    path = params["path"]
    
    case FileOperations.delete_file(user_info[:email], path) do
      :ok ->
        json(conn, %{
          jsonrpc: "2.0",
          result: %{message: "File deleted successfully"},
          id: id
        })
      
      {:error, reason} ->
        json(conn, %{
          jsonrpc: "2.0",
          error: %{code: -32603, message: "Failed to delete file: #{reason}"},
          id: id
        })
    end
  end

  defp handle_get_file_info(conn, params, user_info, id) do
    path = params["path"]
    
    case FileOperations.get_file_info(user_info[:email], path) do
      {:ok, file_info} ->
        json(conn, %{
          jsonrpc: "2.0",
          result: file_info,
          id: id
        })
      
      {:error, reason} ->
        json(conn, %{
          jsonrpc: "2.0",
          error: %{code: -32603, message: "Failed to get file info: #{reason}"},
          id: id
        })
    end
  end

  defp handle_create_directory(conn, params, user_info, id) do
    path = params["path"]
    app_name = params["app_name"]
    
    case FileOperations.create_directory(user_info[:email], path, app_name) do
      {:ok, dir_info} ->
        json(conn, %{
          jsonrpc: "2.0",
          result: %{
            message: "Directory created successfully",
            directory: dir_info
          },
          id: id
        })
      
      {:error, reason} ->
        json(conn, %{
          jsonrpc: "2.0",
          error: %{code: -32603, message: "Failed to create directory: #{reason}"},
          id: id
        })
    end
  end

  defp handle_get_storage_usage(conn, _params, user_info, id) do
    case FileOperations.get_storage_usage(user_info[:email]) do
      {:ok, usage_info} ->
        json(conn, %{
          jsonrpc: "2.0",
          result: usage_info,
          id: id
        })
      
      {:error, reason} ->
        json(conn, %{
          jsonrpc: "2.0",
          error: %{code: -32603, message: "Failed to get storage usage: #{reason}"},
          id: id
        })
    end
  end

  defp get_user_info(conn) do
    case conn.assigns[:current_user] do
      %{email: email, id: user_id} = user -> 
        %{email: email, user_id: user_id, user: user}
      %{id: user_id, email: email} = user -> 
        %{email: email, user_id: user_id, user: user}
      _ -> 
        %{email: nil, user_id: nil, user: nil}
    end
  end
end