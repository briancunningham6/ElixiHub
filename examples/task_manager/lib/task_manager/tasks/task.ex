defmodule TaskManager.Tasks.Task do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tasks" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "pending"
    field :priority, :string, default: "medium"
    field :user_id, :string
    field :assignee_id, :string
    field :due_date, :utc_datetime
    field :completed_at, :utc_datetime
    field :tags, {:array, :string}, default: []
    field :private, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(task, attrs) do
    task
    |> cast(attrs, [:title, :description, :status, :priority, :user_id, :assignee_id, :due_date, :completed_at, :tags, :private])
    |> validate_required([:title, :user_id])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_length(:description, max: 1000)
    |> validate_inclusion(:status, ["pending", "in_progress", "completed", "cancelled"])
    |> validate_inclusion(:priority, ["low", "medium", "high", "urgent"])
    |> validate_change(:status, &validate_status_transition/2)
  end

  defp validate_status_transition(:status, "completed") do
    []
  end

  defp validate_status_transition(:status, status) when status in ["pending", "in_progress", "cancelled"] do
    []
  end

  defp validate_status_transition(:status, _) do
    [status: "is not a valid status"]
  end
end