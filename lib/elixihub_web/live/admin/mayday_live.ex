defmodule ElixihubWeb.Admin.MaydayLive do
  use ElixihubWeb, :live_view
  
  alias Elixihub.Mayday
  alias Elixihub.Accounts
  
  def mount(_params, _session, socket) do
    pools = Mayday.list_pools()
    users = Accounts.list_users()
    
    socket = 
      socket
      |> assign(:pools, pools)
      |> assign(:users, users)
      |> assign(:selected_pool, nil)
      |> assign(:show_pool_form, false)
      |> assign(:pool_form_data, %{})
      |> assign(:show_assignment_form, false)
      |> assign(:assignment_form_data, %{})
    
    {:ok, socket}
  end
  
  def handle_event("show_pool_form", _params, socket) do
    socket = 
      socket
      |> assign(:show_pool_form, true)
      |> assign(:pool_form_data, %{})
    
    {:noreply, socket}
  end
  
  def handle_event("hide_pool_form", _params, socket) do
    socket = assign(socket, :show_pool_form, false)
    {:noreply, socket}
  end
  
  def handle_event("create_pool", %{"pool" => pool_params}, socket) do
    pool_params = Map.put(pool_params, "created_by_id", socket.assigns.current_user.id)
    
    case Mayday.create_pool(pool_params) do
      {:ok, _pool} ->
        pools = Mayday.list_pools()
        
        socket = 
          socket
          |> assign(:pools, pools)
          |> assign(:show_pool_form, false)
          |> put_flash(:info, "Pool created successfully!")
        
        {:noreply, socket}
        
      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create pool: #{inspect(changeset.errors)}")}
    end
  end
  
  def handle_event("select_pool", %{"pool_id" => pool_id}, socket) do
    pool = Mayday.get_pool!(pool_id)
    assignments = Mayday.list_pool_assignments(pool_id)
    stats = Mayday.get_pool_stats(pool_id)
    
    socket = 
      socket
      |> assign(:selected_pool, pool)
      |> assign(:pool_assignments, assignments)
      |> assign(:pool_stats, stats)
    
    {:noreply, socket}
  end
  
  def handle_event("show_assignment_form", %{"pool_id" => pool_id}, socket) do
    socket = 
      socket
      |> assign(:show_assignment_form, true)
      |> assign(:assignment_form_data, %{"pool_id" => pool_id})
    
    {:noreply, socket}
  end
  
  def handle_event("hide_assignment_form", _params, socket) do
    socket = assign(socket, :show_assignment_form, false)
    {:noreply, socket}
  end
  
  def handle_event("assign_user", %{"assignment" => assignment_params}, socket) do
    case Mayday.assign_user_to_pool(
      assignment_params["user_id"], 
      assignment_params["pool_id"], 
      assignment_params["role"]
    ) do
      {:ok, _assignment} ->
        assignments = Mayday.list_pool_assignments(assignment_params["pool_id"])
        stats = Mayday.get_pool_stats(assignment_params["pool_id"])
        
        socket = 
          socket
          |> assign(:pool_assignments, assignments)
          |> assign(:pool_stats, stats)
          |> assign(:show_assignment_form, false)
          |> put_flash(:info, "User assigned successfully!")
        
        {:noreply, socket}
        
      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to assign user: #{inspect(changeset.errors)}")}
    end
  end
  
  def handle_event("remove_assignment", %{"user_id" => user_id, "pool_id" => pool_id}, socket) do
    case Mayday.remove_user_from_pool(user_id, pool_id) do
      {:ok, _} ->
        assignments = Mayday.list_pool_assignments(pool_id)
        stats = Mayday.get_pool_stats(pool_id)
        
        socket = 
          socket
          |> assign(:pool_assignments, assignments)
          |> assign(:pool_stats, stats)
          |> put_flash(:info, "User removed successfully!")
        
        {:noreply, socket}
        
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove user.")}
    end
  end
  
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="py-6">
        <div class="md:flex md:items-center md:justify-between">
          <div class="flex-1 min-w-0">
            <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">
              Mayday Administration
            </h2>
          </div>
          <div class="mt-4 md:mt-0 md:ml-4">
            <button 
              phx-click="show_pool_form"
              class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
            >
              Create Pool
            </button>
          </div>
        </div>
      </div>
      
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Pools List -->
        <div class="lg:col-span-1">
          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
                Assistance Pools
              </h3>
              
              <div class="space-y-3">
                <%= for pool <- @pools do %>
                  <div class={"border rounded-lg p-3 cursor-pointer hover:bg-gray-50 #{if @selected_pool && @selected_pool.id == pool.id, do: "bg-blue-50 border-blue-300", else: "border-gray-200"}"}>
                    <div phx-click="select_pool" phx-value-pool_id={pool.id}>
                      <h4 class="font-medium text-gray-900"><%= pool.name %></h4>
                      <%= if pool.description do %>
                        <p class="text-sm text-gray-600 mt-1"><%= pool.description %></p>
                      <% end %>
                      <div class="flex items-center mt-2 space-x-4 text-xs text-gray-500">
                        <span>Created <%= relative_time(pool.inserted_at) %></span>
                        <span class={"inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium #{if pool.active, do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800"}"}>
                          <%= if pool.active, do: "Active", else: "Inactive" %>
                        </span>
                      </div>
                    </div>
                  </div>
                <% end %>
                
                <%= if length(@pools) == 0 do %>
                  <div class="text-center py-8">
                    <p class="text-gray-500">No pools created yet.</p>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Pool Details -->
        <div class="lg:col-span-2">
          <%= if @selected_pool do %>
            <div class="bg-white overflow-hidden shadow rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <div class="flex items-center justify-between mb-4">
                  <h3 class="text-lg leading-6 font-medium text-gray-900">
                    <%= @selected_pool.name %>
                  </h3>
                  <button 
                    phx-click="show_assignment_form" 
                    phx-value-pool_id={@selected_pool.id}
                    class="inline-flex items-center px-3 py-1 border border-transparent text-sm font-medium rounded-md text-white bg-green-600 hover:bg-green-700"
                  >
                    Assign User
                  </button>
                </div>
                
                <%= if @selected_pool.description do %>
                  <p class="text-sm text-gray-600 mb-4"><%= @selected_pool.description %></p>
                <% end %>
                
                <!-- Stats -->
                <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
                  <div class="bg-blue-50 p-4 rounded-lg">
                    <div class="text-2xl font-bold text-blue-600"><%= @pool_stats.total_tasks %></div>
                    <div class="text-sm text-blue-600">Total Tasks</div>
                  </div>
                  <div class="bg-yellow-50 p-4 rounded-lg">
                    <div class="text-2xl font-bold text-yellow-600"><%= @pool_stats.pending_tasks %></div>
                    <div class="text-sm text-yellow-600">Pending</div>
                  </div>
                  <div class="bg-green-50 p-4 rounded-lg">
                    <div class="text-2xl font-bold text-green-600"><%= @pool_stats.assistants_count %></div>
                    <div class="text-sm text-green-600">Assistants</div>
                  </div>
                  <div class="bg-purple-50 p-4 rounded-lg">
                    <div class="text-2xl font-bold text-purple-600"><%= @pool_stats.users_count %></div>
                    <div class="text-sm text-purple-600">Users</div>
                  </div>
                </div>
                
                <!-- Assignments -->
                <div>
                  <h4 class="font-medium text-gray-900 mb-3">Pool Assignments</h4>
                  <div class="space-y-2">
                    <%= for assignment <- @pool_assignments do %>
                      <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                        <div class="flex items-center space-x-3">
                          <div class={"w-2 h-2 rounded-full #{if assignment.role == "assistant", do: "bg-green-500", else: "bg-blue-500"}"}></div>
                          <div>
                            <div class="font-medium text-gray-900"><%= assignment.user.email %></div>
                            <div class="text-sm text-gray-500">
                              <%= String.capitalize(assignment.role) %>
                              <%= if assignment.user.phone_number do %>
                                | <%= assignment.user.phone_number %>
                              <% end %>
                            </div>
                          </div>
                        </div>
                        <button 
                          phx-click="remove_assignment" 
                          phx-value-user_id={assignment.user.id} 
                          phx-value-pool_id={@selected_pool.id}
                          class="text-red-600 hover:text-red-800 text-sm"
                        >
                          Remove
                        </button>
                      </div>
                    <% end %>
                    
                    <%= if length(@pool_assignments) == 0 do %>
                      <div class="text-center py-8">
                        <p class="text-gray-500">No users assigned to this pool.</p>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          <% else %>
            <div class="bg-white overflow-hidden shadow rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <div class="text-center py-8">
                  <p class="text-gray-500">Select a pool to view details.</p>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    
    <!-- Create Pool Modal -->
    <%= if @show_pool_form do %>
      <div class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
        <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
          <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" aria-hidden="true"></div>
          
          <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>
          
          <div class="relative inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full sm:p-6">
            <form phx-submit="create_pool">
              <div>
                <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Create New Pool</h3>
                
                <div class="space-y-4">
                  <div>
                    <label for="pool_name" class="block text-sm font-medium text-gray-700">Pool Name</label>
                    <input 
                      type="text" 
                      name="pool[name]" 
                      id="pool_name" 
                      required
                      class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
                      placeholder="Enter pool name"
                    >
                  </div>
                  
                  <div>
                    <label for="pool_description" class="block text-sm font-medium text-gray-700">Description</label>
                    <textarea 
                      name="pool[description]" 
                      id="pool_description" 
                      rows="3"
                      class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
                      placeholder="Enter pool description"
                    ></textarea>
                  </div>
                </div>
              </div>
              
              <div class="mt-5 sm:mt-6 sm:grid sm:grid-cols-2 sm:gap-3 sm:grid-flow-row-dense">
                <button 
                  type="submit"
                  class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-blue-600 text-base font-medium text-white hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 sm:col-start-2 sm:text-sm"
                >
                  Create Pool
                </button>
                <button 
                  type="button" 
                  phx-click="hide_pool_form"
                  class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 sm:mt-0 sm:col-start-1 sm:text-sm"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    
    <!-- Assignment Modal -->
    <%= if @show_assignment_form do %>
      <div class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
        <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
          <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" aria-hidden="true"></div>
          
          <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>
          
          <div class="relative inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full sm:p-6">
            <form phx-submit="assign_user">
              <input type="hidden" name="assignment[pool_id]" value={@assignment_form_data["pool_id"]}>
              
              <div>
                <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Assign User to Pool</h3>
                
                <div class="space-y-4">
                  <div>
                    <label for="assignment_user_id" class="block text-sm font-medium text-gray-700">User</label>
                    <select 
                      name="assignment[user_id]" 
                      id="assignment_user_id" 
                      required
                      class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
                    >
                      <option value="">Select a user</option>
                      <%= for user <- @users do %>
                        <option value={user.id}><%= user.email %></option>
                      <% end %>
                    </select>
                  </div>
                  
                  <div>
                    <label for="assignment_role" class="block text-sm font-medium text-gray-700">Role</label>
                    <select 
                      name="assignment[role]" 
                      id="assignment_role" 
                      required
                      class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
                    >
                      <option value="">Select a role</option>
                      <option value="user">User (needs assistance)</option>
                      <option value="assistant">Assistant (provides help)</option>
                    </select>
                  </div>
                </div>
              </div>
              
              <div class="mt-5 sm:mt-6 sm:grid sm:grid-cols-2 sm:gap-3 sm:grid-flow-row-dense">
                <button 
                  type="submit"
                  class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-green-600 text-base font-medium text-white hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 sm:col-start-2 sm:text-sm"
                >
                  Assign User
                </button>
                <button 
                  type="button" 
                  phx-click="hide_assignment_form"
                  class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 sm:mt-0 sm:col-start-1 sm:text-sm"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
  
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