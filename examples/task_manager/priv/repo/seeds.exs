# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     TaskManager.Repo.insert!(%TaskManager.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias TaskManager.Repo
alias TaskManager.Tasks
alias TaskManager.Tasks.Task

# Sample tasks for development
sample_tasks = [
  %{
    title: "Setup development environment",
    description: "Install Elixir, Phoenix, and PostgreSQL",
    status: "completed",
    priority: "high",
    user_id: "admin",
    tags: ["development", "setup"]
  },
  %{
    title: "Create task management system",
    description: "Build a comprehensive task management application",
    status: "in_progress",
    priority: "high",
    user_id: "admin",
    tags: ["development", "feature"]
  },
  %{
    title: "Write documentation",
    description: "Create user guide and API documentation",
    status: "pending",
    priority: "medium",
    user_id: "admin",
    tags: ["documentation"]
  },
  %{
    title: "Deploy to production",
    description: "Set up production environment and deploy application",
    status: "pending",
    priority: "high",
    user_id: "admin",
    tags: ["deployment", "production"]
  }
]

# Only create sample tasks in development environment
if Mix.env() == :dev do
  IO.puts("Creating sample tasks...")
  
  Enum.each(sample_tasks, fn task_attrs ->
    case Tasks.create_task(task_attrs) do
      {:ok, task} ->
        IO.puts("  ✓ Created task: #{task.title}")
      {:error, changeset} ->
        IO.puts("  ✗ Failed to create task: #{task_attrs.title}")
        IO.inspect(changeset.errors)
    end
  end)
  
  IO.puts("Sample tasks created successfully!")
else
  IO.puts("Seeds file executed in #{Mix.env()} environment - no sample data created")
end