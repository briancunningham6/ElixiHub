defmodule Elixihub.Hosts.Host do
  use Ecto.Schema
  import Ecto.Changeset

  schema "hosts" do
    field :name, :string
    field :ip_address, :string
    field :ssh_hostname, :string
    field :ssh_password, :string
    field :ssh_port, :integer, default: 22
    field :description, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(host, attrs) do
    host
    |> cast(attrs, [:name, :ip_address, :ssh_hostname, :ssh_password, :ssh_port, :description])
    |> validate_required([:name, :ip_address, :ssh_hostname, :ssh_port])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_format(:ip_address, ~r/^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/, message: "must be a valid IP address")
    |> validate_format(:ssh_hostname, ~r/^[a-zA-Z0-9.-]+$/, message: "must be a valid hostname or IP address")
    |> validate_number(:ssh_port, greater_than: 0, less_than: 65536)
    |> unique_constraint(:name)
    |> unique_constraint(:ip_address)
  end
end