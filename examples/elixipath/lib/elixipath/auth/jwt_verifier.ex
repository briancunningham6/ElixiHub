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

      # Use Joken to verify the JWT with the same algorithm Guardian uses (HS512)
      signer = Joken.Signer.create("HS512", secret)
      
      case Joken.verify(token, signer) do
        {:ok, claims} ->
          Logger.info("JWT verification successful for user: #{claims["sub"]}")
          Logger.info("Claims: #{inspect(claims)}")
          {:ok, claims}
        {:error, reason} ->
          Logger.error("JWT verification failed: #{inspect(reason)}")
          
          # Try to peek at the token structure for debugging
          case Joken.peek_claims(token) do
            {:ok, peek_claims} ->
              Logger.info("Token structure is valid, claims peek: #{inspect(peek_claims)}")
            {:error, peek_error} ->
              Logger.error("Token structure is invalid: #{inspect(peek_error)}")
          end
          
          {:error, reason}
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
      # Use Joken with HS512 to match ElixiHub's Guardian configuration
      secret = @shared_secret
      signer = Joken.Signer.create("HS512", secret)
      
      # Create a basic config for token generation
      config = Joken.Config.default_claims(default_exp: 3600) 
      
      case Joken.generate_and_sign(config, claims, signer) do
        {:ok, token, _claims} -> {:ok, token}
        {:error, reason} -> 
          Logger.error("Token generation failed: #{inspect(reason)}")
          {:error, :token_generation_failed}
      end
    rescue
      e -> 
        Logger.error("Token generation exception: #{inspect(e)}")
        {:error, :token_generation_failed}
    end
  end
end