# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Elixihub.Repo.insert!(%Elixihub.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Elixihub.Authorization

# Create default permissions
permissions = [
  %{name: "admin:access", description: "Full administrative access"},
  %{name: "user:read", description: "Read user information"},
  %{name: "user:write", description: "Create and update users"},
  %{name: "app:read", description: "View registered applications"},
  %{name: "app:write", description: "Manage applications"},
  %{name: "app:admin", description: "Full application management"},
]

created_permissions = 
  Enum.map(permissions, fn perm_attrs ->
    case Authorization.create_permission(perm_attrs) do
      {:ok, permission} -> permission
      {:error, _changeset} ->
        # Permission might already exist, try to find it
        Elixihub.Repo.get_by(Elixihub.Authorization.Permission, name: perm_attrs.name)
    end
  end)

# Create default roles
admin_role_attrs = %{name: "admin", description: "System administrator"}
user_role_attrs = %{name: "user", description: "Regular user"}

{:ok, admin_role} = 
  case Authorization.create_role(admin_role_attrs) do
    {:ok, role} -> {:ok, role}
    {:error, _changeset} ->
      {:ok, Elixihub.Repo.get_by(Elixihub.Authorization.Role, name: "admin")}
  end

{:ok, user_role} = 
  case Authorization.create_role(user_role_attrs) do
    {:ok, role} -> {:ok, role}
    {:error, _changeset} ->
      {:ok, Elixihub.Repo.get_by(Elixihub.Authorization.Role, name: "user")}
  end

# Assign all permissions to admin role
Enum.each(created_permissions, fn permission ->
  if permission do
    Authorization.assign_permission_to_role(admin_role, permission)
  end
end)

# Assign basic permissions to user role
user_permissions = Enum.filter(created_permissions, fn perm ->
  perm && perm.name in ["user:read", "app:read"]
end)

Enum.each(user_permissions, fn permission ->
  Authorization.assign_permission_to_role(user_role, permission)
end)

IO.puts("Seeded roles and permissions successfully!")

# Create or find admin user and assign admin role
admin_email = "admin@example.com"

admin_user = 
  case Elixihub.Accounts.get_user_by_email(admin_email) do
    nil ->
      # Create admin user if it doesn't exist
      {:ok, user} = Elixihub.Accounts.register_user(%{
        email: admin_email,
        password: "password123456"
      })
      # Confirm the user
      Elixihub.Accounts.User
      |> Elixihub.Repo.get(user.id)
      |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second))
      |> Elixihub.Repo.update!()
      
    existing_user -> existing_user
  end

# Assign admin role to admin user
case Authorization.assign_role_to_user(admin_user, admin_role) do
  {:ok, _user_role} -> 
    IO.puts("Assigned admin role to #{admin_email}")
  {:error, _changeset} -> 
    IO.puts("Admin role already assigned to #{admin_email}")
end

# Create a regular test user
test_user_email = "user@example.com"

test_user = 
  case Elixihub.Accounts.get_user_by_email(test_user_email) do
    nil ->
      {:ok, user} = Elixihub.Accounts.register_user(%{
        email: test_user_email,
        password: "password123456"
      })
      # Confirm the user
      Elixihub.Accounts.User
      |> Elixihub.Repo.get(user.id)
      |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second))
      |> Elixihub.Repo.update!()
      
    existing_user -> existing_user
  end

# Assign user role to test user
case Authorization.assign_role_to_user(test_user, user_role) do
  {:ok, _user_role} -> 
    IO.puts("Assigned user role to #{test_user_email}")
  {:error, _changeset} -> 
    IO.puts("User role already assigned to #{test_user_email}")
end

# Create sample applications
sample_apps = [
  %{
    name: "TaskMaster Pro",
    description: "Advanced task and project management application for teams and individuals. Features include real-time collaboration, time tracking, and detailed reporting.",
    url: "https://taskmaster.example.com",
    status: "active"
  },
  %{
    name: "DataViz Dashboard",
    description: "Business intelligence and data visualization platform. Create interactive charts, dashboards, and reports from your data sources.",
    url: "https://dataviz.example.com",
    status: "active"
  },
  %{
    name: "DevOps Monitor", 
    description: "Infrastructure monitoring and alerting system. Track server health, application performance, and deployment metrics.",
    url: "https://devops-monitor.example.com",
    status: "active"
  },
  %{
    name: "Code Review Portal",
    description: "Collaborative code review and quality assurance platform. Streamline your development workflow with automated checks.",
    url: "https://code-review.example.com", 
    status: "pending"
  },
  %{
    name: "Knowledge Base",
    description: "Internal documentation and knowledge sharing platform. Create, organize, and share team knowledge effectively.",
    url: "https://kb.example.com",
    status: "active"
  }
]

created_apps = 
  Enum.map(sample_apps, fn app_attrs ->
    case Elixihub.Apps.create_app(app_attrs) do
      {:ok, app} -> app
      {:error, _changeset} ->
        # App might already exist, try to find it
        Elixihub.Repo.get_by(Elixihub.Apps.App, name: app_attrs.name)
    end
  end)

IO.puts("Seeded #{length(Enum.filter(created_apps, & &1))} sample applications!")
