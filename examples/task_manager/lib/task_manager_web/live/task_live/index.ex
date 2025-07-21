defmodule TaskManagerWeb.TaskLive.Index do
  use TaskManagerWeb, :live_view

  alias TaskManager.Tasks
  alias TaskManager.Tasks.Task

  on_mount {TaskManagerWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    # Current user is guaranteed to exist due to on_mount callback
    current_user = socket.assigns.current_user
    user_id = current_user.id
    tasks = Tasks.list_tasks_by_user(user_id)
    
    socket = 
      socket
      |> assign(:tasks, tasks)
      |> assign(:user_id, user_id)
      |> assign(:filter_status, "all")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Task")
    |> assign(:task, Tasks.get_task!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Task")
    |> assign(:task, %Task{user_id: socket.assigns.user_id})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Task Manager")
    |> assign(:task, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    task = Tasks.get_task!(id)
    {:ok, _} = Tasks.delete_task(task)

    tasks = Tasks.list_tasks_by_user(socket.assigns.user_id)
    {:noreply, assign(socket, :tasks, tasks)}
  end

  @impl true
  def handle_event("complete", %{"id" => id}, socket) do
    task = Tasks.get_task!(id)
    {:ok, _} = Tasks.complete_task(task)

    tasks = Tasks.list_tasks_by_user(socket.assigns.user_id)
    {:noreply, assign(socket, :tasks, tasks)}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    user_id = socket.assigns.user_id
    
    tasks = case status do
      "all" -> Tasks.list_tasks_by_user(user_id)
      _ -> Tasks.list_tasks_by_user(user_id) |> Enum.filter(&(&1.status == status))
    end

    socket = 
      socket
      |> assign(:tasks, tasks)
      |> assign(:filter_status, status)

    {:noreply, socket}
  end

  @impl true
  def handle_info({TaskManagerWeb.TaskLive.FormComponent, {:saved, task}}, socket) do
    tasks = Tasks.list_tasks_by_user(socket.assigns.user_id)
    {:noreply, assign(socket, :tasks, tasks)}
  end

  # No longer needed - user info comes from conn assigns
  # defp get_user_id(session) do
  #   session["current_user"]["sub"]
  # end

  defp status_color(status) do
    case status do
      "pending" -> "gray"
      "in_progress" -> "blue"
      "completed" -> "green"
      "cancelled" -> "red"
      _ -> "gray"
    end
  end

  defp priority_color(priority) do
    case priority do
      "low" -> "gray"
      "medium" -> "yellow"
      "high" -> "orange"
      "urgent" -> "red"
      _ -> "gray"
    end
  end
end