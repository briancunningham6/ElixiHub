defmodule ElixiPath.Auth.JWTVerifier do
  @moduledoc """
  JWT token verification for ElixiPath using ElixiHub's shared secret
  """
  require Logger

  # Use the same shared secret as ElixiHub
  @shared_secret "dev_secret_key_32_chars_long_exactly_for_jwt_signing"

  def verify(token) do
    try do
      Logger.info("JWT verification starting for token: #{String.slice(token, 0, 50)}...")
      Logger.info("Using secret: #{String.slice(@shared_secret, 0, 10)}...")

      # Use the same secret as ElixiHub (from dev.exs)
      secret = @shared_secret
      Logger.info("Using secret: #{String.slice(secret, 0, 10)}...")

      # Use JOSE to verify the JWT with the same algorithm Guardian uses (HS512)
      signer = Joken.Signer.create("HS512", secret)
      
      case JOSE.JWT.verify(signer.jwk, token) do
        {true, %JOSE.JWT{fields: claims}, _jws} ->
          Logger.info("JWT verification successful for user: #{claims["sub"]}")
          Logger.info("Claims: #{inspect(claims)}")
          {:ok, claims}
        {false, _, _} ->
          Logger.error("JWT verification failed: invalid signature")
          {:error, :invalid_signature}
      end
    rescue
      error ->
        Logger.error("JWT verification error: #{inspect(error)}")
        Logger.error("Error stacktrace: #{inspect(__STACKTRACE__)}")
        {:error, :verification_error}
    end
  end

  def generate_token(claims) do
    try do
      # Use JOSE directly like Task Manager
      secret = @shared_secret
      jwk = JOSE.JWK.from_oct(secret)
      
      case JOSE.JWT.sign(jwk, %{"alg" => "HS256"}, claims) do
        {_jws, token} -> {:ok, token}
        error -> 
          Logger.error("Token generation failed: #{inspect(error)}")
          {:error, :token_generation_failed}
      end
    rescue
      e -> 
        Logger.error("Token generation exception: #{inspect(e)}")
        {:error, :token_generation_failed}
    end
  end
end