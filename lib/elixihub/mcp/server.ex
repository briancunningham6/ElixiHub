defmodule Elixihub.MCP.Server do
  use Ecto.Schema
  import Ecto.Changeset

  alias Elixihub.Apps.App
  alias Elixihub.MCP.Tool

  @valid_statuses ["active", "inactive", "maintenance", "error"]

  schema "mcp_servers" do
    field :name, :string
    field :url, :string
    field :description, :string
    field :version, :string
    field :status, :string, default: "active"
    field :metadata, :map, default: %{}

    belongs_to :app, App
    has_many :tools, Tool, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(server, attrs) do
    server
    |> cast(attrs, [:name, :url, :description, :version, :status, :metadata, :app_id])
    |> validate_required([:name, :url, :app_id])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_format(:url, ~r/^https?:\/\//)
    |> unique_constraint(:app_id, message: "App can only have one MCP server")
    |> foreign_key_constraint(:app_id)
  end
end