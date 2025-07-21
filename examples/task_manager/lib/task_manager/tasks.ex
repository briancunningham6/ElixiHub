defmodule TaskManager.Tasks do
  @moduledoc """
  The Tasks context.
  """

  import Ecto.Query, warn: false
  alias TaskManager.Repo
  alias TaskManager.Tasks.Task

  def list_tasks do
    Task
    |> where([t], t.private == false)
    |> Repo.all()
  end

  def list_tasks_by_user(user_id) when not is_nil(user_id) do
    Task
    |> where([t], t.user_id == ^user_id)
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end

  def list_public_tasks do
    Task
    |> where([t], t.private == false)
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end
  
  def list_tasks_by_user(_user_id), do: []

  def list_tasks_by_status(status) do
    Task
    |> where([t], t.status == ^status and t.private == false)
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end

  def list_tasks_by_status_for_user(status, user_id) do
    Task
    |> where([t], t.status == ^status and t.user_id == ^user_id)
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end

  def get_task!(id), do: Repo.get!(Task, id)

  def create_task(attrs \\ %{}) do
    %Task{}
    |> Task.changeset(attrs)
    |> Repo.insert()
  end

  def update_task(%Task{} = task, attrs) do
    task
    |> Task.changeset(attrs)
    |> Repo.update()
  end

  def delete_task(%Task{} = task) do
    Repo.delete(task)
  end

  def change_task(%Task{} = task, attrs \\ %{}) do
    Task.changeset(task, attrs)
  end

  def complete_task(%Task{} = task) do
    update_task(task, %{status: "completed", completed_at: DateTime.utc_now()})
  end

  def get_task_stats do
    total = Repo.aggregate(Task, :count, :id)
    completed = Task |> where([t], t.status == "completed") |> Repo.aggregate(:count, :id)
    pending = Task |> where([t], t.status == "pending") |> Repo.aggregate(:count, :id)
    in_progress = Task |> where([t], t.status == "in_progress") |> Repo.aggregate(:count, :id)

    %{
      total: total,
      completed: completed,
      pending: pending,
      in_progress: in_progress
    }
  end
end