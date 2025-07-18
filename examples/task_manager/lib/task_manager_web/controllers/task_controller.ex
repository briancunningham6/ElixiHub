defmodule TaskManagerWeb.TaskController do
  use TaskManagerWeb, :controller

  alias TaskManager.Tasks
  alias TaskManager.Tasks.Task

  def index(conn, _params) do
    user_id = get_user_id(conn)
    tasks = Tasks.list_tasks_by_user(user_id)
    render(conn, :index, tasks: tasks)
  end

  def create(conn, %{"task" => task_params}) do
    user_id = get_user_id(conn)
    task_params = Map.put(task_params, "user_id", user_id)

    case Tasks.create_task(task_params) do
      {:ok, task} ->
        conn
        |> put_status(:created)
        |> render(:show, task: task)
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    task = Tasks.get_task!(id)
    
    if can_access_task?(conn, task) do
      render(conn, :show, task: task)
    else
      conn
      |> put_status(:forbidden)
      |> render(:error, message: "Access denied")
    end
  end

  def update(conn, %{"id" => id, "task" => task_params}) do
    task = Tasks.get_task!(id)
    
    if can_modify_task?(conn, task) do
      case Tasks.update_task(task, task_params) do
        {:ok, task} ->
          render(conn, :show, task: task)
        {:error, %Ecto.Changeset{} = changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> render(:error, changeset: changeset)
      end
    else
      conn
      |> put_status(:forbidden)
      |> render(:error, message: "Access denied")
    end
  end

  def delete(conn, %{"id" => id}) do
    task = Tasks.get_task!(id)
    
    if can_modify_task?(conn, task) do
      {:ok, _task} = Tasks.delete_task(task)
      send_resp(conn, :no_content, "")
    else
      conn
      |> put_status(:forbidden)
      |> render(:error, message: "Access denied")
    end
  end

  def complete(conn, %{"id" => id}) do
    task = Tasks.get_task!(id)
    
    if can_modify_task?(conn, task) do
      case Tasks.complete_task(task) do
        {:ok, task} ->
          render(conn, :show, task: task)
        {:error, %Ecto.Changeset{} = changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> render(:error, changeset: changeset)
      end
    else
      conn
      |> put_status(:forbidden)
      |> render(:error, message: "Access denied")
    end
  end

  def stats(conn, _params) do
    stats = Tasks.get_task_stats()
    render(conn, :stats, stats: stats)
  end

  defp get_user_id(conn) do
    conn.assigns.current_user["sub"]
  end

  defp can_access_task?(conn, task) do
    user_id = get_user_id(conn)
    user_permissions = conn.assigns.user_permissions
    
    task.user_id == user_id || 
    task.assignee_id == user_id || 
    user_permissions.can_admin
  end

  defp can_modify_task?(conn, task) do
    user_id = get_user_id(conn)
    user_permissions = conn.assigns.user_permissions
    
    task.user_id == user_id || 
    user_permissions.can_write || 
    user_permissions.can_admin
  end
end