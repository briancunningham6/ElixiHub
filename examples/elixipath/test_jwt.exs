#!/usr/bin/env elixir

# Test JWT verification for ElixiPath
Mix.install([
  {:jason, "~> 1.4"},
  {:joken, "~> 2.6"}
])

# The JWT token from the error
token = "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJlbGl4aWh1YiIsImVtYWlsIjoiYWRtaW5AZXhhbXBsZS5jb20iLCJleHAiOjE3NTYzOTEzNDUsImlhdCI6MTc1Mzk3MjE0NSwiaXNzIjoiZWxpeGlodWIiLCJqdGkiOiIzYzNkNDVlNC1mYmRkLTQwMjItOTIzZi05ZTZlY2UyNzg1MzkiLCJuYmYiOjE3NTM5NzIxNDQsInN1YiI6IjMiLCJ0eXAiOiJhY2Nlc3MiLCJ1c2VybmFtZSI6ImFkbWluQGV4YW1wbGUuY29tIn0.HEuTShkbcMnMzyYX-orBZgYKLaX6FNHIIEsZn2meBShPUoTP0qwkCPe1pIq7YUvn7mEnfGB3LYibqj_qkiHAjQ"

# The shared secret from ElixiPath
shared_secret = "dev_secret_key_32_chars_long_exactly_for_jwt_signing"

IO.puts("=== JWT TOKEN DEBUG ===")
IO.puts("Token: #{String.slice(token, 0, 50)}...")
IO.puts("Secret: #{String.slice(shared_secret, 0, 10)}...")

# Test 1: Manual decoding
IO.puts("\n=== MANUAL DECODING ===")
[header_b64, payload_b64, _signature_b64] = String.split(token, ".")

add_padding = fn s ->
  padding_needed = rem(4 - rem(String.length(s), 4), 4)
  s <> String.duplicate("=", padding_needed)
end

header = Jason.decode!(Base.url_decode64!(add_padding.(header_b64)))
payload = Jason.decode!(Base.url_decode64!(add_padding.(payload_b64)))

IO.puts("Header: #{inspect(header)}")
IO.puts("Payload: #{inspect(payload)}")

# Test 2: Joken verification (like ElixiPath does)
IO.puts("\n=== JOKEN VERIFICATION ===")
signer = Joken.Signer.create("HS512", shared_secret)

case Joken.verify(token, signer) do
  {:ok, claims} ->
    IO.puts("✅ Joken.verify SUCCESS")
    IO.puts("Claims: #{inspect(claims)}")
  {:error, reason} ->
    IO.puts("❌ Joken.verify FAILED")
    IO.puts("Error: #{inspect(reason)}")
end

# Test 3: Check token expiry
current_time = System.system_time(:second)
IO.puts("\n=== TIME VALIDATION ===")
IO.puts("Current time: #{current_time}")
IO.puts("Token exp: #{payload["exp"]}")
IO.puts("Token iat: #{payload["iat"]}")
IO.puts("Token nbf: #{payload["nbf"]}")

is_expired = payload["exp"] < current_time
is_not_yet_valid = payload["nbf"] > current_time

IO.puts("Expired? #{is_expired}")  
IO.puts("Not yet valid? #{is_not_yet_valid}")

if is_expired do
  IO.puts("⚠️  TOKEN IS EXPIRED!")
  expired_for = current_time - payload["exp"]
  IO.puts("Expired #{expired_for} seconds ago")
end

# Test 4: Try with Joken config (like ElixiPath token_config)
IO.puts("\n=== JOKEN WITH CONFIG ===")

defmodule TestJWT do
  use Joken.Config
  
  def token_config do
    default_claims(skip: [:aud, :iss])
    |> add_claim("aud", fn -> "elixihub" end, &(&1 == "elixihub"))
    |> add_claim("iss", fn -> "elixihub" end, &(&1 == "elixihub"))
  end
end

case Joken.verify_and_validate(TestJWT.token_config(), token, signer) do
  {:ok, claims} ->
    IO.puts("✅ Joken.verify_and_validate SUCCESS")
    IO.puts("Claims: #{inspect(claims)}")
  {:error, reason} ->
    IO.puts("❌ Joken.verify_and_validate FAILED")
    IO.puts("Error: #{inspect(reason)}")
end