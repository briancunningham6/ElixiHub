# JWT Debug Script
require Logger

token = "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJlbGl4aWh1YiIsImVtYWlsIjoiYWRtaW5AZXhhbXBsZS5jb20iLCJleHAiOjE3NTYzOTEzNDUsImlhdCI6MTc1Mzk3MjE0NSwiaXNzIjoiZWxpeGlodWIiLCJqdGkiOiIzYzNkNDVlNC1mYmRkLTQwMjItOTIzZi05ZTZlY2UyNzg1MzkiLCJuYmYiOjE3NTM5NzIxNDQsInN1YiI6IjMiLCJ0eXAiOiJhY2Nlc3MiLCJ1c2VybmFtZSI6ImFkbWluQGV4YW1wbGUuY29tIn0.HEuTShkbcMnMzyYX-orBZgYKLaX6FNHIIEsZn2meBShPUoTP0qwkCPe1pIq7YUvn7mEnfGB3LYibqj_qkiHAjQ"

IO.puts("=== JWT TOKEN ANALYSIS ===")
IO.puts("Token: #{String.slice(token, 0..50)}...")

# Decode token manually
[header_b64, payload_b64, signature_b64] = String.split(token, ".")

# Add padding if needed
add_padding = fn s ->
  padding_needed = rem(4 - rem(String.length(s), 4), 4)
  s <> String.duplicate("=", padding_needed)
end

header_json = header_b64 |> add_padding.() |> Base.url_decode64!()
payload_json = payload_b64 |> add_padding.() |> Base.url_decode64!()

header = Jason.decode!(header_json)
payload = Jason.decode!(payload_json)

IO.puts("\n=== JWT HEADER ===")
IO.inspect(header, pretty: true)

IO.puts("\n=== JWT PAYLOAD ===")
IO.inspect(payload, pretty: true)

# Convert timestamps
current_time = System.system_time(:second)
IO.puts("\n=== TIME ANALYSIS ===")
IO.puts("Current Unix timestamp: #{current_time}")
IO.puts("Token issued at (iat): #{payload["iat"]} -> #{DateTime.from_unix!(payload["iat"])}")
IO.puts("Token expires at (exp): #{payload["exp"]} -> #{DateTime.from_unix!(payload["exp"])}")
IO.puts("Token not before (nbf): #{payload["nbf"]} -> #{DateTime.from_unix!(payload["nbf"])}")

# Check if token is expired
is_expired = payload["exp"] < current_time
is_not_yet_valid = payload["nbf"] > current_time

IO.puts("Is expired? #{is_expired}")
IO.puts("Is not yet valid? #{is_not_yet_valid}")

# Test with ElixiPath JWT verifier
IO.puts("\n=== ELIXIPATH JWT VERIFIER TEST ===")

# Load the ElixiPath application
Code.require_file("examples/elixipath/lib/elixipath/auth/jwt_verifier.ex")

case ElixiPath.Auth.JWTVerifier.verify(token) do
  {:ok, claims} ->
    IO.puts("✅ JWT verification SUCCESSFUL")
    IO.puts("Verified claims:")
    IO.inspect(claims, pretty: true)
  
  {:error, reason} ->
    IO.puts("❌ JWT verification FAILED")
    IO.puts("Error: #{inspect(reason)}")
end

# Test ElixiPath Auth.verify_token
IO.puts("\n=== ELIXIPATH AUTH VERIFY_TOKEN TEST ===")
Code.require_file("examples/elixipath/lib/elixipath/auth.ex")

case ElixiPath.Auth.verify_token(token) do
  {:ok, user} ->
    IO.puts("✅ Auth.verify_token SUCCESSFUL")
    IO.puts("User data:")
    IO.inspect(user, pretty: true)
  
  {:error, reason} ->
    IO.puts("❌ Auth.verify_token FAILED")  
    IO.puts("Error: #{inspect(reason)}")
end