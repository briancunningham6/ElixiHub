defmodule HelloWorldApp.Auth.ElixiHubAuth.JWTVerifier do
  @moduledoc """
  JWT token verification for ElixiHub integration.
  
  This module handles JWT token verification using the same algorithm and secret
  as ElixiHub's Guardian configuration. It's been tested to work correctly with
  ElixiHub's HS512 JWT tokens.
  """
  require Logger

  @doc """
  Verifies a JWT token from ElixiHub.
  
  Uses HS512 algorithm to match ElixiHub's Guardian configuration.
  Includes comprehensive error handling and logging for debugging.
  """
  def verify(token) do
    try do
      Logger.info("JWT verification starting for token: #{String.slice(token, 0, 50)}...")
      
      secret = HelloWorldApp.Auth.ElixiHubAuth.get_shared_secret()
      Logger.info("Using secret: #{String.slice(secret, 0, 10)}...")

      # Use JOSE to verify the JWT with HS512 algorithm (Guardian's default)
      signer = Joken.Signer.create("HS512", secret)
      
      case JOSE.JWT.verify(signer.jwk, token) do
        {true, %JOSE.JWT{fields: claims}, _jws} ->
          Logger.info("JWT verification successful for user: #{claims["sub"]}")
          Logger.debug("Claims: #{inspect(claims)}")
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

  @doc """
  Generates a JWT token for testing or development purposes.
  
  ## Example
      iex> claims = %{
      ...>   "sub" => "test-user",
      ...>   "email" => "test@example.com",
      ...>   "aud" => "elixihub",
      ...>   "iss" => "elixihub",
      ...>   "exp" => System.system_time(:second) + 3600
      ...> }
      iex> JWTVerifier.generate_token(claims)
      {:ok, "eyJhbGciOiJIUzUxMiJ9..."}
  """
  def generate_token(claims) do
    try do
      secret = HelloWorldApp.Auth.ElixiHubAuth.get_shared_secret()
      jwk = JOSE.JWK.from_oct(secret)
      
      case JOSE.JWT.sign(jwk, %{"alg" => "HS512"}, claims) do
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