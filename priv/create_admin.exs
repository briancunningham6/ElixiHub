# Script to create an admin user for testing
# Run with: mix run priv/create_admin.exs

alias Elixihub.Accounts
alias Elixihub.Authorization

# Try to get existing admin user or create new one
user = case Accounts.get_user_by_email("admin@elixihub.local") do
  nil ->
    admin_attrs = %{
      email: "admin@elixihub.local",
      password: "adminpassword123"
    }
    
    case Accounts.register_user(admin_attrs) do
      {:ok, user} ->
        IO.puts("Created admin user: #{user.email}")
        user
      {:error, changeset} ->
        IO.puts("Failed to create admin user:")
        IO.inspect(changeset.errors)
        nil
    end
  
  existing_user ->
    IO.puts("Using existing admin user: #{existing_user.email}")
    existing_user
end

if user do
  # Get admin role
  admin_role = Elixihub.Repo.get_by(Elixihub.Authorization.Role, name: "admin")
  
  if admin_role do
    # Assign admin role
    case Authorization.assign_role_to_user(user, admin_role) do
      {:ok, _} ->
        IO.puts("Assigned admin role to user")
      {:error, error} ->
        IO.puts("Failed to assign admin role: #{inspect(error)}")
    end
  else
    IO.puts("Admin role not found. Make sure seeds have been run.")
  end
end