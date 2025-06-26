defmodule Elixihub.Repo do
  use Ecto.Repo,
    otp_app: :elixihub,
    adapter: Ecto.Adapters.Postgres
end
