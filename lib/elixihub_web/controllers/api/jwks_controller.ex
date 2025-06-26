defmodule ElixihubWeb.Api.JwksController do
  use ElixihubWeb, :controller

  def index(conn, _params) do
    jwks = %{
      keys: [
        %{
          kty: "oct",
          use: "sig",
          alg: "HS256",
          k: get_secret_key() |> Base.url_encode64(padding: false)
        }
      ]
    }

    conn
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> json(jwks)
  end

  defp get_secret_key do
    Application.get_env(:elixihub, Elixihub.Guardian)[:secret_key]
  end
end