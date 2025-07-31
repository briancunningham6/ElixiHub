#!/usr/bin/env elixir

# Debug JWT secret configuration differences
IO.puts("=== JWT SECRET CONFIGURATION ANALYSIS ===\n")

# 1. ElixiHub Guardian Configuration Analysis
IO.puts("1. ElixiHub Guardian Configuration:")
IO.puts("   config.exs secret_key: 'your-256-bit-secret-key-here'")
IO.puts("   dev.exs secret_key: 'dev_secret_key_32_chars_long_exactly_for_jwt_signing'")
IO.puts("   Length: #{String.length("dev_secret_key_32_chars_long_exactly_for_jwt_signing")} characters")

# 2. ElixiPath JWTVerifier Configuration
IO.puts("\n2. ElixiPath JWTVerifier Configuration:")
elixipath_secret = "dev_secret_key_32_chars_long_exactly_for_jwt_signing"
IO.puts("   @shared_secret: '#{elixipath_secret}'")
IO.puts("   Length: #{String.length(elixipath_secret)} characters")

# 3. Analysis of the failing JWT token from the error
token = "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJlbGl4aWh1YiIsImVtYWlsIjoiYWRtaW5AZXhhbXBsZS5jb20iLCJleHAiOjE3NTYzOTEzNDUsImlhdCI6MTc1Mzk3MjE0NSwiaXNzIjoiZWxpeGlodWIiLCJqdGkiOiIzYzNkNDVlNC1mYmRkLTQwMjItOTIzZi05ZTZlY2UyNzg1MzkiLCJuYmYiOjE3NTM5NzIxNDQsInN1YiI6IjMiLCJ0eXAiOiJhY2Nlc3MiLCJ1c2VybmFtZSI6ImFkbWluQGV4YW1wbGUuY29tIn0.HEuTShkbcMnMzyYX-orBZgYKLaX6FNHIIEsZn2meBShPUoTP0qwkCPe1pIq7YUvn7mEnfGB3LYibqj_qkiHAjQ"

IO.puts("\n3. JWT Token Analysis:")
[header_b64, payload_b64, signature_b64] = String.split(token, ".")

add_padding = fn s ->
  padding_needed = rem(4 - rem(String.length(s), 4), 4)
  s <> String.duplicate("=", padding_needed)
end

header_json = header_b64 |> add_padding.() |> Base.url_decode64!()
payload_json = payload_b64 |> add_padding.() |> Base.url_decode64!()

header = Jason.decode!(header_json)
payload = Jason.decode!(payload_json)

IO.puts("   Algorithm from header: #{header["alg"]}")
IO.puts("   Token type: #{header["typ"]}")
IO.puts("   Issuer: #{payload["iss"]}")
IO.puts("   Audience: #{payload["aud"]}")

# 4. JWKS endpoint analysis  
IO.puts("\n4. JWKS Endpoint Analysis:")
IO.puts("   ElixiHub JWKS endpoint advertises: HS256 algorithm")
IO.puts("   But Guardian may be using a different algorithm")

# 5. Configuration inheritance analysis
IO.puts("\n5. Configuration Inheritance Analysis:")
IO.puts("   config.exs defines: secret_key: 'your-256-bit-secret-key-here'")
IO.puts("   dev.exs overrides:  secret_key: 'dev_secret_key_32_chars_long_exactly_for_jwt_signing'")
IO.puts("   In dev environment, dev.exs config should take precedence")

# 6. Guardian default algorithm analysis
IO.puts("\n6. Guardian Default Algorithm:")
IO.puts("   Guardian typically uses HS512 as default algorithm")
IO.puts("   Token header shows: #{header["alg"]}")
IO.puts("   JWKS endpoint advertises: HS256")
IO.puts("   This mismatch could be the issue!")

IO.puts("\n=== CONCLUSION ===")
IO.puts("Issue 1: Algorithm Mismatch")
IO.puts("  - Guardian is generating tokens with HS512") 
IO.puts("  - JWKS endpoint advertises HS256")
IO.puts("  - ElixiPath might be trying both but still failing")

IO.puts("\nIssue 2: Potential Secret Mismatch")
IO.puts("  - Need to verify which secret ElixiHub Guardian is actually using")
IO.puts("  - Need to check if there are environment variables overriding the config")

IO.puts("\nIssue 3: Time-based Token Issues")
current_time = System.system_time(:second)
IO.puts("  - Current time: #{current_time}")
IO.puts("  - Token exp: #{payload["exp"]}")
if payload["exp"] < current_time do
  IO.puts("  - TOKEN IS EXPIRED! This could be the real issue.")
else
  IO.puts("  - Token is still valid time-wise")
end