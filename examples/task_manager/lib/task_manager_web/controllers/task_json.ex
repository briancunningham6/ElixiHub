defmodule TaskManagerWeb.TaskJSON do
  alias TaskManager.Tasks.Task

  @doc """
  Renders a list of tasks.
  """
  def index(%{tasks: tasks}) do
    %{data: for(task <- tasks, do: data(task))}
  end

  @doc """
  Renders a single task.
  """
  def show(%{task: task}) do
    %{data: data(task)}
  end

  @doc """
  Renders task statistics.
  """
  def stats(%{stats: stats}) do
    %{data: stats}
  end

  @doc """
  Renders errors.
  """
  def error(%{message: message}) do
    %{errors: %{detail: message}}
  end

  def error(%{changeset: changeset}) do
    %{errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)}
  end

  defp data(%Task{} = task) do
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

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end