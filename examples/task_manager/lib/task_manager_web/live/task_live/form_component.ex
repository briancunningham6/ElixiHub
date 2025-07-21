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

      <.simple_form
        for={@form}
        id="task-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:user_id]} type="hidden" />
        <.input field={@form[:title]} type="text" label="Title" />
        <.input field={@form[:description]} type="textarea" label="Description" />
        <.input
          field={@form[:status]}
          type="select"
          label="Status"
          prompt="Choose a status"
          options={[
            {"Pending", "pending"},
            {"In Progress", "in_progress"},
            {"Completed", "completed"},
            {"Cancelled", "cancelled"}
          ]}
        />
        <.input
          field={@form[:priority]}
          type="select"
          label="Priority"
          prompt="Choose a priority"
          options={[
            {"Low", "low"},
            {"Medium", "medium"},
            {"High", "high"},
            {"Urgent", "urgent"}
          ]}
        />
        <.input field={@form[:due_date]} type="datetime-local" label="Due Date" />
        <.input field={@form[:assignee_id]} type="text" label="Assignee ID" />
        <.input field={@form[:tags]} type="text" label="Tags (comma separated)" />
        <.input field={@form[:private]} type="checkbox" label="Private task (only visible to you)" />
        
        <:actions>
          <.button phx-disable-with="Saving...">Save Task</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{task: task} = assigns, socket) do
    # Convert tags list to string for form display, but keep the original task for validation
    display_task = %{task | tags: format_tags(task.tags)}
    changeset = Tasks.change_task(display_task)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:original_task, task)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"task" => task_params}, socket) do
    # Process tags and private field for validation too
    processed_params = 
      task_params
      |> process_tags()
      |> process_private()
    
    # Use the original task for validation (which has proper array tags)
    base_task = Map.get(socket.assigns, :original_task, socket.assigns.task)
    
    changeset =
      base_task
      |> Tasks.change_task(processed_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"task" => task_params}, socket) do
    task_params = 
      task_params
      |> process_tags()
      |> process_private()
    IO.puts("=== SAVE TASK PARAMS ===")
    IO.inspect(task_params)
    save_task(socket, socket.assigns.action, task_params)
  end

  defp save_task(socket, :edit, task_params) do
    base_task = Map.get(socket.assigns, :original_task, socket.assigns.task)
    case Tasks.update_task(base_task, task_params) do
      {:ok, task} ->
        notify_parent({:saved, task})

        {:noreply,
         socket
         |> put_flash(:info, "Task updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_task(socket, :new, task_params) do
    IO.puts("=== CREATING NEW TASK ===")
    IO.inspect(task_params)
    
    case Tasks.create_task(task_params) do
      {:ok, task} ->
        IO.puts("=== TASK CREATED SUCCESSFULLY ===")
        notify_parent({:saved, task})

        {:noreply,
         socket
         |> put_flash(:info, "Task created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.puts("=== TASK CREATION FAILED ===")
        IO.inspect(changeset.errors)
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
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
  
  defp process_tags(%{"tags" => tags} = params) when is_list(tags) do
    # Tags is already a list, no processing needed
    params
  end

  defp process_tags(params), do: params

  defp process_private(%{"private" => private} = params) when private in ["on", "true", true] do
    Map.put(params, "private", true)
  end
  
  defp process_private(%{"private" => _} = params) do
    Map.put(params, "private", false)
  end
  
  defp process_private(params) do
    Map.put(params, "private", false)
  end
  
  defp clean_empty_values(params) do
    params
    |> Enum.reject(fn {_key, value} -> value == "" or value == nil end)
    |> Enum.into(%{})
  end
  
  defp format_tags(tags) when is_list(tags), do: Enum.join(tags, ", ")
  defp format_tags(_), do: ""
end