# Test JWT round-trip: generate and verify with ElixiPath
IO.puts("Testing JWT round-trip with ElixiPath:")

# Test claims similar to what Guardian would generate
claims = %{
  "aud" => "elixihub",
  "email" => "admin@example.com", 
  "exp" => System.system_time(:second) + 3600,
  "iat" => System.system_time(:second),
  "iss" => "elixihub",
  "jti" => "test-jti-123",
  "nbf" => System.system_time(:second),
  "sub" => "3",
  "typ" => "access",
  "username" => "admin@example.com"
}

# Generate token
IO.puts("1. Generating token...")
case ElixiPath.Auth.JWTVerifier.generate_token(claims) do
  {:ok, token} ->
    IO.puts("✅ Token generated successfully")
    IO.puts("Token: #{String.slice(token, 0, 50)}...")
    
    # Verify the token we just generated
    IO.puts("\n2. Verifying generated token...")
    case ElixiPath.Auth.JWTVerifier.verify(token) do
      {:ok, verified_claims} ->
        IO.puts("✅ Round-trip successful!")
        IO.inspect(verified_claims, label: "Verified Claims")
      {:error, reason} ->
        IO.puts("❌ Round-trip failed!")
        IO.inspect(reason, label: "Verification Error")
    end
    
  {:error, reason} ->
    IO.puts("❌ Token generation failed!")
    IO.inspect(reason, label: "Generation Error")
end

# Also test the original Guardian token
IO.puts("\n3. Testing original Guardian token:")
guardian_token = "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJlbGl4aWh1YiIsImVtYWlsIjoiYWRtaW5AZXhhbXBsZS5jb20iLCJleHAiOjE3NTY0NzcxMTksImlhdCI6MTc1NDA1NzkxOSwiaXNzIjoiZWxpeGlodWIiLCJqdGkiOiJhZmQxMGU5Ni04M2FjLTQzOWQtOTM3Ny05NjQ5M2Y0MTUwZGIiLCJuYmYiOjE3NTQwNTc5MTgsInN1YiI6IjMiLCJ0eXAiOiJhY2Nlc3MiLCJ1c2VybmFtZSI6ImFkbWluQGV4YW1wbGUuY29tIn0.9KVWdC4xBAVLtDJE7HgHdlBq_H2NvUi5vJgDjBDg5_nqKiOy_EqgpkYRG_zbx3KiLU9gHo8_pTECgP4o_Zv8dQ"

case ElixiPath.Auth.JWTVerifier.verify(guardian_token) do
  {:ok, claims} ->
    IO.puts("✅ Guardian token verified!")
    IO.inspect(claims, label: "Guardian Claims")
  {:error, reason} ->
    IO.puts("❌ Guardian token failed!")
    IO.inspect(reason, label: "Guardian Error")
end