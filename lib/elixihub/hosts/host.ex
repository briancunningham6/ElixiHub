defmodule Elixihub.Hosts.Host do
  use Ecto.Schema
  import Ecto.Changeset

  schema "hosts" do
    field :name, :string
    field :ip_address, :string
    field :ssh_username, :string
    field :ssh_password, :string
    field :ssh_port, :integer, default: 22
    field :description, :string
    field :architecture, :string, default: "MacOs(Apple Silicon)"

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(host, attrs) do
    host
    |> cast(attrs, [:name, :ip_address, :ssh_username, :ssh_password, :ssh_port, :description, :architecture])
    |> validate_required([:name, :ip_address, :ssh_username, :ssh_port, :architecture])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_format(:ip_address, ~r/^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/, message: "must be a valid IP address")
    |> validate_number(:ssh_port, greater_than: 0, less_than: 65536)
    |> validate_inclusion(:architecture, ["MacOs(Apple Silicon)", "ARM64(Raspberry Pi)"], message: "must be a valid architecture")
    |> unique_constraint(:name)
    |> unique_constraint(:ip_address)
  end
end