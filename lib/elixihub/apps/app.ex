defmodule Elixihub.Apps.App do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_statuses ["active", "inactive", "pending"]

  schema "apps" do
    field :name, :string
    field :status, :string, default: "pending"
    field :description, :string
    field :url, :string
    field :api_key, :string
    
    belongs_to :node, Elixihub.Nodes.Node

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(app, attrs) do
    app
    |> cast(attrs, [:name, :description, :url, :status, :node_id])
    |> validate_required([:name, :description, :url])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_format(:url, ~r/^https?:\/\//)
    |> generate_api_key()
    |> unique_constraint(:api_key)
    |> unique_constraint(:name)
  end

  @doc false
  def update_changeset(app, attrs) do
    app
    |> cast(attrs, [:name, :description, :url, :status, :node_id])
    |> validate_required([:name, :description, :url])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_format(:url, ~r/^https?:\/\//)
    |> unique_constraint(:name)
  end

  defp generate_api_key(changeset) do
    case get_field(changeset, :api_key) do
      nil -> put_change(changeset, :api_key, generate_unique_api_key())
      _ -> changeset
    end
  end

  defp generate_unique_api_key do
    "app_" <> (:crypto.strong_rand_bytes(32) |> Base.encode64() |> binary_part(0, 32))
  end
end
