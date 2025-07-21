defmodule ElixihubWeb.JWKSController do
  use ElixihubWeb, :controller

  def jwks(conn, _params) do
    # Since we're using Guardian with HS256 (shared secret), we provide basic JWKS information
    # For HS256, we don't expose the actual secret key, just the key metadata
    jwks = %{
      "keys" => [
        %{
          "kty" => "oct",
          "use" => "sig",
          "kid" => "elixihub-key",
          "alg" => "HS256"
        }
      ]
    }
    
    conn
    |> put_resp_content_type("application/json")
    |> json(jwks)
  end
end