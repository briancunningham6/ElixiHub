defmodule TaskManagerWeb.TaskHTML do
  use TaskManagerWeb, :html

  def index(assigns) do
    ~H"""
    <div class="tasks-index">
      <h1>Tasks</h1>
      <div class="tasks-list">
        <%= for task <- @tasks do %>
          <div class="task-item">
            <h3><%= task.title %></h3>
            <p><%= task.description %></p>
            <div class="task-meta">
              <span class={["status", task.status]}><%= task.status %></span>
              <span class={["priority", task.priority]}><%= task.priority %></span>
              <%= if task.due_date do %>
                <span class="due-date">Due: <%= Calendar.strftime(task.due_date, "%Y-%m-%d") %></span>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def show(assigns) do
    ~H"""
    <div class="task-show">
      <h1><%= @task.title %></h1>
      <p><%= @task.description %></p>
      <div class="task-details">
        <p><strong>Status:</strong> <%= @task.status %></p>
        <p><strong>Priority:</strong> <%= @task.priority %></p>
        <%= if @task.due_date do %>
          <p><strong>Due Date:</strong> <%= Calendar.strftime(@task.due_date, "%Y-%m-%d %H:%M") %></p>
        <% end %>
        <%= if @task.tags && length(@task.tags) > 0 do %>
          <p><strong>Tags:</strong> <%= Enum.join(@task.tags, ", ") %></p>
        <% end %>
      </div>
    </div>
    """
  end

  def error(assigns) do
    ~H"""
    <div class="error">
      <h2>Error</h2>
      <%= if assigns[:message] do %>
        <p><%= @message %></p>
      <% end %>
      <%= if assigns[:changeset] do %>
        <ul>
          <%= for {field, errors} <- @changeset.errors do %>
            <li><%= field %>: <%= Enum.join(errors, ", ") %></li>
          <% end %>
        </ul>
      <% end %>
    </div>
    """
  end

  def stats(assigns) do
    ~H"""
    <div class="task-stats">
      <h2>Task Statistics</h2>
      <div class="stats-grid">
        <div class="stat-item">
          <h3><%= @stats.total %></h3>
          <p>Total Tasks</p>
        </div>
        <div class="stat-item">
          <h3><%= @stats.pending %></h3>
          <p>Pending</p>
        </div>
        <div class="stat-item">
          <h3><%= @stats.in_progress %></h3>
          <p>In Progress</p>
        </div>
        <div class="stat-item">
          <h3><%= @stats.completed %></h3>
          <p>Completed</p>
        </div>
      </div>
    </div>
    """
  end
end