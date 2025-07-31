#!/usr/bin/env elixir

# Test Guardian and Joken compatibility
Application.put_env(:elixihub, Elixihub.Guardian,
  issuer: "elixihub",
  secret_key: "dev_secret_key_32_chars_long_exactly_for_jwt_signing"
)



defmodule TestUser do
  defstruct id: 1, email: "test@example.com"
end

defmodule TestGuardian do
  use Guardian, otp_app: :elixihub
  
  def subject_for_token(user, _claims) do
    {:ok, to_string(user.id)}
  end
  
  def build_claims(claims, user, _opts) do
    updated_claims = claims
    |> Map.put("username", user.email)
    |> Map.put("email", user.email)
    
    {:ok, updated_claims}
  end
  
  def resource_from_claims(%{"sub" => id}) do
    {:ok, %TestUser{id: String.to_integer(id)}}
  end
end

IO.puts("=== GUARDIAN/JOKEN COMPATIBILITY TEST ===")

user = %TestUser{id: 3, email: "admin@example.com"}

# Generate token with Guardian (like ElixiHub does)
IO.puts("\n=== GUARDIAN TOKEN GENERATION ===")
case TestGuardian.encode_and_sign(user) do
  {:ok, token, claims} ->
    IO.puts("✅ Guardian token generated successfully")
    IO.puts("Token: #{String.slice(token, 0, 50)}...")
    IO.puts("Claims: #{inspect(claims)}")
    
    # Try to verify with Joken (like ElixiPath does)
    IO.puts("\n=== JOKEN VERIFICATION ===")
    secret = "dev_secret_key_32_chars_long_exactly_for_jwt_signing"
    signer = Joken.Signer.create("HS512", secret)
    
    case Joken.verify(token, signer) do
      {:ok, joken_claims} ->
        IO.puts("✅ Joken verification successful")
        IO.puts("Joken claims: #{inspect(joken_claims)}")
      {:error, reason} ->
        IO.puts("❌ Joken verification failed: #{inspect(reason)}")
    end
    
    # Also try with other algorithms
    IO.puts("\n=== TRYING DIFFERENT ALGORITHMS ===")
    
    algorithms = ["HS256", "HS384", "HS512"]
    for alg <- algorithms do
      IO.puts("Trying #{alg}...")
      test_signer = Joken.Signer.create(alg, secret)
      case Joken.verify(token, test_signer) do
        {:ok, _} -> IO.puts("  ✅ #{alg} worked!")
        {:error, _} -> IO.puts("  ❌ #{alg} failed")
      end
    end
    
  {:error, reason} ->
    IO.puts("❌ Guardian token generation failed: #{inspect(reason)}")
end