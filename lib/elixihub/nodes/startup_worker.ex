defmodule Elixihub.Nodes.StartupWorker do
  @moduledoc """
  Worker to ensure current node is registered on application startup.
  """
  
  use GenServer
  alias Elixihub.Nodes

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    # Ensure current node is registered after a short delay
    # to allow the database to be ready
    Process.send_after(self(), :ensure_current_node, 1000)
    {:ok, state}
  end

  @impl true
  def handle_info(:ensure_current_node, state) do
    case Nodes.ensure_current_node() do
      {:ok, _node} ->
        IO.puts("Current ElixiHub node registered successfully")
      
      {:error, reason} ->
        IO.puts("Failed to register current node: #{inspect(reason)}")
        # Retry after 5 seconds
        Process.send_after(self(), :ensure_current_node, 5000)
    end
    
    {:noreply, state}
  end
end