defmodule Elixihub.MCP.Tool do
  use Ecto.Schema
  import Ecto.Changeset

  alias Elixihub.MCP.Server

  schema "mcp_tools" do
    field :name, :string
    field :description, :string
    field :input_schema, :map, default: %{}
    field :metadata, :map, default: %{}

    belongs_to :server, Server

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tool, attrs) do
    tool
    |> cast(attrs, [:name, :description, :input_schema, :metadata, :server_id])
    |> validate_required([:name, :description, :server_id])
    |> unique_constraint([:server_id, :name], message: "Tool name must be unique within a server")
    |> foreign_key_constraint(:server_id)
  end
end