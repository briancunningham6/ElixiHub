defmodule Elixihub.SSOJWT do
  @moduledoc """
  Joken-based JWT generation for SSO compatibility with ElixiPath.
  Uses the same secret and algorithm as ElixiPath for perfect compatibility.
  """
  require Logger

  # Use the same shared secret as ElixiPath and Guardian
  @shared_secret "dev_secret_key_32_chars_long_exactly_for_jwt_signing"

  def generate_sso_token(user) do
    try do
      # Create claims similar to Guardian but compatible with ElixiPath
      claims = %{
        "aud" => "elixihub",
        "email" => user.email,
        "exp" => System.system_time(:second) + 3600, # 1 hour
        "iat" => System.system_time(:second),
        "iss" => "elixihub", 
        "jti" => generate_jti(),
        "nbf" => System.system_time(:second),
        "sub" => to_string(user.id),
        "typ" => "access",
        "username" => user.email
      }

      # Use exact same approach as ElixiPath
      secret = @shared_secret
      signer = Joken.Signer.create("HS512", secret)
      
      # Create a basic config for token generation
      config = Joken.Config.default_claims(default_exp: 3600)
      
      case Joken.generate_and_sign(config, claims, signer) do
        {:ok, token, _claims} -> 
          Logger.info("SSO JWT token generated successfully for user: #{user.id}")
          {:ok, token}
        {:error, reason} -> 
          Logger.error("SSO JWT token generation failed: #{inspect(reason)}")
          {:error, :token_generation_failed}
      end
    rescue
      e -> 
        Logger.error("SSO JWT token generation exception: #{inspect(e)}")
        {:error, :token_generation_failed}
    end
  end

  def verify_sso_token(token) do
    try do
      secret = @shared_secret
      signer = Joken.Signer.create("HS512", secret)
      
      case Joken.verify(token, signer) do
        {:ok, claims} ->
          {:ok, claims}
        {:error, reason} ->
          Logger.error("SSO JWT verification failed: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("SSO JWT verification error: #{inspect(error)}")
        {:error, :verification_error}
    end
  end

  defp generate_jti do
    # Generate a unique identifier for the token
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end