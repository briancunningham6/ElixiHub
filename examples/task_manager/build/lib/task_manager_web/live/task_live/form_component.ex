defmodule TaskManagerWeb.TaskLive.FormComponent do
  use TaskManagerWeb, :live_component

  alias TaskManager.Tasks

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage task records in your database.</:subtitle>
      </.header>

      <.form
        for={@form}
        id="task-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-6">
          <.input name="task[title]" type="text" label="Title" value={@form.data.title} />
          <.input name="task[description]" type="textarea" label="Description" value={@form.data.description} />
          <.input
            name="task[status]"
            type="select"
            label="Status"
            value={@form.data.status}
            prompt="Choose a status"
            options={[
              {"Pending", "pending"},
              {"In Progress", "in_progress"},
              {"Completed", "completed"},
              {"Cancelled", "cancelled"}
            ]}
          />
          <.input
            name="task[priority]"
            type="select"
            label="Priority"
            value={@form.data.priority}
            prompt="Choose a priority"
            options={[
              {"Low", "low"},
              {"Medium", "medium"},
              {"High", "high"},
              {"Urgent", "urgent"}
            ]}
          />
          <.input name="task[due_date]" type="datetime-local" label="Due Date" value={@form.data.due_date} />
          <.input name="task[assignee_id]" type="text" label="Assignee ID" value={@form.data.assignee_id} />
          <.input name="task[tags]" type="text" label="Tags (comma separated)" value={format_tags(@form.data.tags)} />
          
          <div class="flex items-center justify-end space-x-4">
            <.button phx-disable-with="Saving...">Save Task</.button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{task: task} = assigns, socket) do
    changeset = Tasks.change_task(task)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"task" => task_params}, socket) do
    changeset =
      socket.assigns.task
      |> Tasks.change_task(task_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"task" => task_params}, socket) do
    task_params = process_tags(task_params)
    save_task(socket, socket.assigns.action, task_params)
  end

  defp save_task(socket, :edit, task_params) do
    case Tasks.update_task(socket.assigns.task, task_params) do
      {:ok, task} ->
        notify_parent({:saved, task})

        {:noreply,
         socket
         |> put_flash(:info, "Task updated successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_task(socket, :new, task_params) do
    case Tasks.create_task(task_params) do
      {:ok, task} ->
        notify_parent({:saved, task})

        {:noreply,
         socket
         |> put_flash(:info, "Task created successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, changeset)
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp process_tags(%{"tags" => tags_string} = params) when is_binary(tags_string) do
    tags = 
      tags_string
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
    
    Map.put(params, "tags", tags)
  end

  defp process_tags(params), do: params
  
  defp format_tags(tags) when is_list(tags), do: Enum.join(tags, ", ")
  defp format_tags(_), do: ""
end