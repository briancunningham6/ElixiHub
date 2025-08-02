# Test SSO JWT compatibility between ElixiHub and ElixiPath
IO.puts("Testing ElixiHub SSO JWT generation...")

# Create a fake user struct for testing  
fake_user = %{
  id: 3,
  email: "admin@example.com"
}

case Elixihub.SSOJWT.generate_sso_token(fake_user) do
  {:ok, token} ->
    IO.puts("✅ Token generated successfully!")
    IO.puts("JWT Token: #{token}")
    
    # Show first 100 characters for verification
    IO.puts("Token preview: #{String.slice(token, 0, 100)}...")
    
  {:error, reason} ->
    IO.puts("❌ Token generation failed!")
    IO.inspect(reason, label: "Error")
end