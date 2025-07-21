defmodule TaskManager.Auth.JWTVerifier do
  @moduledoc """
  JWT token verification using ElixiHub's shared secret (HS512).
  """

  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def verify(token) do
    GenServer.call(__MODULE__, {:verify, token})
  end

  def init(_) do
    Logger.info("JWT Verifier started - using HS512 shared secret")
    {:ok, %{}}
  end

  def handle_call({:verify, token}, _from, state) do
    IO.puts("Verifying JWT with shared secret...")
    result = verify_token(token)
    {:reply, result, state}
  end

  defp verify_token(token) do
    try do
      Logger.info("Attempting to verify JWT token: #{String.slice(token, 0, 50)}...")
      
      # Use the same secret as ElixiHub (from dev.exs)
      secret = "dev_secret_key_32_chars_long_exactly_for_jwt_signing"
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
end
