# Check what apps exist
apps = Elixihub.Apps.list_apps()
IO.puts("=== APPS ===")
Enum.each(apps, fn app -> 
  IO.puts("App: #{app.name} (ID: #{app.id}) - Status: #{app.deployment_status}")
end)

# Check system roles
IO.puts("\n=== SYSTEM ROLES ===")
system_roles = Elixihub.Authorization.list_roles()
Enum.each(system_roles, fn role ->
  IO.puts("System Role: #{role.name} (ID: #{role.id})")
end)

# Check app roles
IO.puts("\n=== APP ROLES ===")
Enum.each(apps, fn app ->
  app_roles = Elixihub.Apps.list_app_roles(app.id)
  IO.puts("App #{app.name} roles:")
  Enum.each(app_roles, fn role ->
    IO.puts("  - #{role.identifier}: #{role.name}")
  end)
end)

# Check users and their roles
IO.puts("\n=== USERS AND THEIR ROLES ===")
users = Elixihub.Accounts.list_users()
Enum.each(users, fn user ->
  IO.puts("User: #{user.email} (ID: #{user.id})")
  
  # System roles
  system_roles = Elixihub.Authorization.get_user_system_roles(user)
  Enum.each(system_roles, fn role ->
    IO.puts("  System Role: #{role.name}")
  end)
  
  # App roles
  app_roles = Elixihub.Authorization.get_user_app_roles(user)
  Enum.each(app_roles, fn role ->
    IO.puts("  App Role: #{role.identifier}: #{role.name} (App: #{role.app.name})")
  end)
end)