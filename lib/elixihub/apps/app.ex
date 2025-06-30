defmodule Elixihub.Apps.App do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_statuses ["active", "inactive", "pending"]
  @valid_deployment_statuses ["pending", "deploying", "deployed", "failed"]

  schema "apps" do
    field :name, :string
    field :status, :string, default: "pending"
    field :description, :string
    field :url, :string
    field :api_key, :string
    
    # Deployment fields
    field :deployment_status, :string, default: "pending"
    field :deployment_log, :map, default: %{}
    field :deployed_at, :utc_datetime
    field :deploy_path, :string
    field :ssh_host, :string
    field :ssh_port, :integer, default: 22
    field :ssh_username, :string
    
    belongs_to :node, Elixihub.Nodes.Node
    belongs_to :host, Elixihub.Hosts.Host
    has_many :app_roles, Elixihub.Apps.AppRole

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(app, attrs) do
    app
    |> cast(attrs, [:name, :description, :url, :status, :node_id, :host_id, :deployment_status, :deployment_log, :deployed_at, :deploy_path, :ssh_host, :ssh_port, :ssh_username])
    |> validate_required([:name, :description, :url])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:deployment_status, @valid_deployment_statuses)
    |> validate_format(:url, ~r/^https?:\/\//)
    |> validate_number(:ssh_port, greater_than: 0, less_than: 65536)
    |> generate_api_key()
    |> unique_constraint(:api_key)
    |> unique_constraint(:name)
  end

  @doc false
  def update_changeset(app, attrs) do
    app
    |> cast(attrs, [:name, :description, :url, :status, :node_id, :host_id, :deployment_status, :deployment_log, :deployed_at, :deploy_path, :ssh_host, :ssh_port, :ssh_username])
    |> validate_required([:name, :description, :url])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:deployment_status, @valid_deployment_statuses)
    |> validate_format(:url, ~r/^https?:\/\//)
    |> validate_number(:ssh_port, greater_than: 0, less_than: 65536)
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
