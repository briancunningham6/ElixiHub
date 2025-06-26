defmodule Elixihub.Nodes.Node do
  use Ecto.Schema
  import Ecto.Changeset

  schema "nodes" do
    field :name, :string
    field :port, :integer
    field :status, :string
    field :host, :string
    field :description, :string
    field :cookie, :string
    field :is_current, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(node, attrs) do
    node
    |> cast(attrs, [:name, :host, :port, :cookie, :description, :status, :is_current])
    |> validate_required([:name, :host, :port, :cookie])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_format(:host, ~r/^[a-zA-Z0-9.-]+$/, message: "must be a valid hostname or IP address")
    |> validate_number(:port, greater_than: 0, less_than: 65536)
    |> validate_inclusion(:status, ["connected", "disconnected", "error", "connecting"])
    |> put_status_default(attrs)
    |> unique_constraint(:name)
    |> validate_current_node()
  end

  defp put_status_default(changeset, attrs) do
    # Handle both string and atom keys, don't override if status is already set
    status = attrs["status"] || attrs[:status] || get_field(changeset, :status) || "disconnected"
    put_change(changeset, :status, status)
  end

  defp validate_current_node(changeset) do
    if get_change(changeset, :is_current) == true do
      # Ensure only one node can be marked as current
      changeset
    else
      changeset
    end
  end
end
