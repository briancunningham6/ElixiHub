defmodule ElixihubWeb.MaydayLive do
  use ElixihubWeb, :live_view
  
  alias Elixihub.Mayday
  alias Elixihub.Accounts
  
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    
    # Check if user is assigned to any pools as assistant
    user_pools = Mayday.get_user_pools(user.id)
    assistant_pools = Enum.filter(user_pools, &(&1.role == "assistant"))
    
    if length(assistant_pools) > 0 do
      # Load available tasks for assistant
      available_tasks = Mayday.list_available_tasks_for_assistant(user.id)
      assigned_tasks = Mayday.list_assigned_tasks(user.id)
      
      socket = 
        socket
        |> assign(:available_tasks, available_tasks)
        |> assign(:assigned_tasks, assigned_tasks)
        |> assign(:user_pools, assistant_pools)
        |> assign(:view_mode, :volunteer)
        |> assign(:selected_task, nil)
      
      {:ok, socket}
    else
      # Check if user has any pools as regular user
      user_pools = Enum.filter(user_pools, &(&1.role == "user"))
      
      socket = 
        socket
        |> assign(:user_pools, user_pools)
        |> assign(:view_mode, :user)
        |> assign(:user_tasks, [])
      
      {:ok, socket}
    end
  end
  
  def handle_event("claim_task", %{"task_id" => task_id}, socket) do
    user_id = socket.assigns.current_user.id
    
    case Mayday.claim_task(task_id, user_id) do
      {:ok, _task} ->
        # Refresh task lists
        available_tasks = Mayday.list_available_tasks_for_assistant(user_id)
        assigned_tasks = Mayday.list_assigned_tasks(user_id)
        
        socket = 
          socket
          |> assign(:available_tasks, available_tasks)
          |> assign(:assigned_tasks, assigned_tasks)
          |> put_flash(:info, "Task claimed successfully!")
        
        {:noreply, socket}
        
      {:error, :task_not_available} ->
        {:noreply, put_flash(socket, :error, "Task is no longer available.")}
        
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to claim task.")}
    end
  end
  
  def handle_event("complete_task", %{"task_id" => task_id}, socket) do
    user_id = socket.assigns.current_user.id
    
    case Mayday.complete_task(task_id, user_id) do
      {:ok, _task} ->
        # Refresh task lists
        available_tasks = Mayday.list_available_tasks_for_assistant(user_id)
        assigned_tasks = Mayday.list_assigned_tasks(user_id)
        
        socket = 
          socket
          |> assign(:available_tasks, available_tasks)
          |> assign(:assigned_tasks, assigned_tasks)
          |> put_flash(:info, "Task completed successfully!")
        
        {:noreply, socket}
        
      {:error, :not_authorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to complete this task.")}
        
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to complete task.")}
    end
  end
  
  def handle_event("view_task", %{"task_id" => task_id}, socket) do
    task = Mayday.get_task!(task_id)
    socket = assign(socket, :selected_task, task)
    {:noreply, socket}
  end
  
  def handle_event("close_task_modal", _params, socket) do
    socket = assign(socket, :selected_task, nil)
    {:noreply, socket}
  end
  
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="py-6">
        <div class="md:flex md:items-center md:justify-between">
          <div class="flex-1 min-w-0">
            <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">
              <%= if @view_mode == :volunteer do %>
                Volunteer Dashboard
              <% else %>
                My Mayday Account
              <% end %>
            </h2>
          </div>
        </div>
      </div>
      
      <%= if @view_mode == :volunteer do %>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <!-- Available Tasks -->
          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
                Available Tasks
                <span class="ml-2 bg-blue-100 text-blue-800 text-xs font-medium px-2.5 py-0.5 rounded-full">
                  <%= length(@available_tasks) %>
                </span>
              </h3>
              
              <div class="space-y-4">
                <%= for task <- @available_tasks do %>
                  <div class="border rounded-lg p-4 hover:bg-gray-50">
                    <div class="flex items-start justify-between">
                      <div class="flex-1">
                        <h4 class="text-sm font-medium text-gray-900"><%= task.title %></h4>
                        <p class="text-sm text-gray-500 mt-1"><%= task.description %></p>
                        <div class="flex items-center mt-2 space-x-4">
                          <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{priority_color(task.priority)}"}>
                            <%= String.capitalize(task.priority) %>
                          </span>
                          <%= if task.category do %>
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                              <%= String.capitalize(task.category) %>
                            </span>
                          <% end %>
                          <span class="text-xs text-gray-500">
                            <%= relative_time(task.inserted_at) %>
                          </span>
                        </div>
                        <%= if task.caller do %>
                          <div class="mt-2 text-sm text-gray-600">
                            <span class="font-medium">Caller:</span> <%= task.caller.email %>
                            <%= if task.caller.phone_number do %>
                              | <%= task.caller.phone_number %>
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                      <div class="flex space-x-2">
                        <button 
                          phx-click="view_task" 
                          phx-value-task_id={task.id}
                          class="inline-flex items-center px-3 py-1 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
                        >
                          View
                        </button>
                        <button 
                          phx-click="claim_task" 
                          phx-value-task_id={task.id}
                          class="inline-flex items-center px-3 py-1 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
                        >
                          Claim
                        </button>
                      </div>
                    </div>
                  </div>
                <% end %>
                
                <%= if length(@available_tasks) == 0 do %>
                  <div class="text-center py-8">
                    <p class="text-gray-500">No tasks available at the moment.</p>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
          
          <!-- Assigned Tasks -->
          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
                My Assigned Tasks
                <span class="ml-2 bg-green-100 text-green-800 text-xs font-medium px-2.5 py-0.5 rounded-full">
                  <%= length(@assigned_tasks) %>
                </span>
              </h3>
              
              <div class="space-y-4">
                <%= for task <- @assigned_tasks do %>
                  <div class="border rounded-lg p-4 hover:bg-gray-50">
                    <div class="flex items-start justify-between">
                      <div class="flex-1">
                        <h4 class="text-sm font-medium text-gray-900"><%= task.title %></h4>
                        <p class="text-sm text-gray-500 mt-1"><%= task.description %></p>
                        <div class="flex items-center mt-2 space-x-4">
                          <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{priority_color(task.priority)}"}>
                            <%= String.capitalize(task.priority) %>
                          </span>
                          <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{status_color(task.status)}"}>
                            <%= String.capitalize(task.status) %>
                          </span>
                          <span class="text-xs text-gray-500">
                            Claimed <%= relative_time(task.claimed_at) %>
                          </span>
                        </div>
                        <%= if task.caller do %>
                          <div class="mt-2 text-sm text-gray-600">
                            <span class="font-medium">Caller:</span> <%= task.caller.email %>
                            <%= if task.caller.phone_number do %>
                              | <%= task.caller.phone_number %>
                            <% end %>
                            <%= if task.caller.address do %>
                              <br><span class="font-medium">Address:</span> <%= task.caller.address %>
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                      <div class="flex space-x-2">
                        <button 
                          phx-click="view_task" 
                          phx-value-task_id={task.id}
                          class="inline-flex items-center px-3 py-1 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
                        >
                          View
                        </button>
                        <button 
                          phx-click="complete_task" 
                          phx-value-task_id={task.id}
                          class="inline-flex items-center px-3 py-1 border border-transparent text-sm font-medium rounded-md text-white bg-green-600 hover:bg-green-700"
                        >
                          Complete
                        </button>
                      </div>
                    </div>
                  </div>
                <% end %>
                
                <%= if length(@assigned_tasks) == 0 do %>
                  <div class="text-center py-8">
                    <p class="text-gray-500">No assigned tasks.</p>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% else %>
        <!-- User View -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
              Welcome to Mayday
            </h3>
            
            <%= if length(@user_pools) > 0 do %>
              <div class="mb-6">
                <h4 class="text-sm font-medium text-gray-900 mb-2">Your Assistance Pools:</h4>
                <div class="space-y-2">
                  <%= for pool <- @user_pools do %>
                    <div class="flex items-center p-3 bg-gray-50 rounded-lg">
                      <div class="flex-1">
                        <h5 class="font-medium text-gray-900"><%= pool.pool.name %></h5>
                        <%= if pool.pool.description do %>
                          <p class="text-sm text-gray-600"><%= pool.pool.description %></p>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
              
              <div class="bg-blue-50 p-4 rounded-lg">
                <h4 class="font-medium text-blue-900 mb-2">How to get help:</h4>
                <ol class="list-decimal list-inside space-y-1 text-sm text-blue-800">
                  <li>Call our Mayday assistance line</li>
                  <li>Describe what help you need</li>
                  <li>A volunteer from your assistance pool will be notified</li>
                  <li>They will contact you to arrange assistance</li>
                </ol>
              </div>
            <% else %>
              <div class="bg-yellow-50 p-4 rounded-lg">
                <h4 class="font-medium text-yellow-900 mb-2">Account Setup Required</h4>
                <p class="text-sm text-yellow-800">
                  You are not currently assigned to any assistance pools. Please contact your administrator to be assigned to a pool.
                </p>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    
    <!-- Task Details Modal -->
    <%= if @selected_task do %>
      <div class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
        <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
          <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" aria-hidden="true"></div>
          
          <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>
          
          <div class="relative inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-2xl sm:w-full sm:p-6">
            <div class="absolute top-0 right-0 pt-4 pr-4">
              <button type="button" phx-click="close_task_modal" class="bg-white rounded-md text-gray-400 hover:text-gray-600">
                <span class="sr-only">Close</span>
                <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            
            <div class="sm:flex sm:items-start">
              <div class="mt-3 text-center sm:mt-0 sm:text-left w-full">
                <h3 class="text-lg leading-6 font-medium text-gray-900" id="modal-title">
                  Task Details
                </h3>
                <div class="mt-4 space-y-4">
                  <div>
                    <h4 class="font-medium text-gray-900"><%= @selected_task.title %></h4>
                    <p class="text-sm text-gray-600 mt-1"><%= @selected_task.description %></p>
                  </div>
                  
                  <div class="grid grid-cols-2 gap-4">
                    <div>
                      <span class="text-sm font-medium text-gray-500">Priority:</span>
                      <span class={"ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{priority_color(@selected_task.priority)}"}>
                        <%= String.capitalize(@selected_task.priority) %>
                      </span>
                    </div>
                    <div>
                      <span class="text-sm font-medium text-gray-500">Status:</span>
                      <span class={"ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{status_color(@selected_task.status)}"}>
                        <%= String.capitalize(@selected_task.status) %>
                      </span>
                    </div>
                    <%= if @selected_task.category do %>
                      <div>
                        <span class="text-sm font-medium text-gray-500">Category:</span>
                        <span class="ml-2 text-sm text-gray-900"><%= String.capitalize(@selected_task.category) %></span>
                      </div>
                    <% end %>
                    <div>
                      <span class="text-sm font-medium text-gray-500">Created:</span>
                      <span class="ml-2 text-sm text-gray-900"><%= relative_time(@selected_task.inserted_at) %></span>
                    </div>
                  </div>
                  
                  <%= if @selected_task.caller do %>
                    <div class="border-t pt-4">
                      <h5 class="font-medium text-gray-900 mb-2">Caller Information</h5>
                      <div class="space-y-2">
                        <div>
                          <span class="text-sm font-medium text-gray-500">Email:</span>
                          <span class="ml-2 text-sm text-gray-900"><%= @selected_task.caller.email %></span>
                        </div>
                        <%= if @selected_task.caller.phone_number do %>
                          <div>
                            <span class="text-sm font-medium text-gray-500">Phone:</span>
                            <span class="ml-2 text-sm text-gray-900"><%= @selected_task.caller.phone_number %></span>
                          </div>
                        <% end %>
                        <%= if @selected_task.caller.address do %>
                          <div>
                            <span class="text-sm font-medium text-gray-500">Address:</span>
                            <span class="ml-2 text-sm text-gray-900"><%= @selected_task.caller.address %></span>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                  
                  <%= if @selected_task.ai_analysis do %>
                    <div class="border-t pt-4">
                      <h5 class="font-medium text-gray-900 mb-2">AI Analysis</h5>
                      <div class="bg-gray-50 p-3 rounded-lg">
                        <pre class="text-sm text-gray-700 whitespace-pre-wrap"><%= @selected_task.ai_analysis %></pre>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
  
  defp priority_color("urgent"), do: "bg-red-100 text-red-800"
  defp priority_color("high"), do: "bg-orange-100 text-orange-800"
  defp priority_color("medium"), do: "bg-yellow-100 text-yellow-800"
  defp priority_color("low"), do: "bg-green-100 text-green-800"
  defp priority_color(_), do: "bg-gray-100 text-gray-800"
  
  defp status_color("pending"), do: "bg-blue-100 text-blue-800"
  defp status_color("claimed"), do: "bg-yellow-100 text-yellow-800"
  defp status_color("in_progress"), do: "bg-orange-100 text-orange-800"
  defp status_color("completed"), do: "bg-green-100 text-green-800"
  defp status_color("cancelled"), do: "bg-red-100 text-red-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"
  
  defp relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)
    
    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      true -> "#{div(diff, 86400)} days ago"
    end
  end
end