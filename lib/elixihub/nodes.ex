defmodule Elixihub.Nodes do
  @moduledoc """
  The Nodes context for managing Elixir node connections.
  """

  import Ecto.Query, warn: false
  alias Elixihub.Repo

  alias Elixihub.Nodes.Node

  @doc """
  Returns the list of nodes.
  """
  def list_nodes do
    Repo.all(Node)
  end

  @doc """
  Gets a single node.

  Raises `Ecto.NoResultsError` if the Node does not exist.
  """
  def get_node!(id), do: Repo.get!(Node, id)

  @doc """
  Gets the current node (the one marked as is_current: true).
  """
  def get_current_node do
    Repo.get_by(Node, is_current: true)
  end

  @doc """
  Creates a node.
  """
  def create_node(attrs \\ %{}) do
    %Node{}
    |> Node.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a node.
  """
  def update_node(%Node{} = node, attrs) do
    # If setting this node as current, unset all other current nodes first
    if attrs["is_current"] == true or attrs[:is_current] == true do
      unset_all_current_nodes()
    end
    
    node
    |> Node.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a node.
  """
  def delete_node(%Node{} = node) do
    Repo.delete(node)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking node changes.
  """
  def change_node(%Node{} = node, attrs \\ %{}) do
    Node.changeset(node, attrs)
  end

  @doc """
  Connects to a remote node.
  """
  def connect_to_node(%Node{} = node) do
    current_node = :erlang.node()
    
    cond do
      # If this is the current node and we're not in distributed mode
      node.is_current and current_node == :nonode@nohost ->
        update_node(node, %{status: "connected"})
        {:ok, node}
        
      # If this is the current node and we're in distributed mode
      node.is_current ->
        update_node(node, %{status: "connected"})
        {:ok, node}
        
      # If we're not in distributed mode, we can't connect to remote nodes
      current_node == :nonode@nohost ->
        update_node(node, %{status: "error"})
        {:error, "Cannot connect to remote nodes: ElixiHub is not running in distributed mode. Start with: elixir --name elixihub@localhost -S mix phx.server"}
        
      # Normal distributed node connection
      true ->
        node_name = String.to_atom("#{node.name}@#{node.host}")
        
        # Set the cookie for the connection
        :erlang.set_cookie(node_name, String.to_atom(node.cookie))
        
        case :net_kernel.connect_node(node_name) do
          true ->
            update_node(node, %{status: "connected"})
            {:ok, node}
          
          false ->
            update_node(node, %{status: "error"})
            {:error, "Failed to connect to node"}
          
          :ignored ->
            {:error, "Connection attempt ignored (node already connected or local)"}
        end
    end
  end

  @doc """
  Disconnects from a remote node.
  """
  def disconnect_from_node(%Node{} = node) do
    node_name = String.to_atom("#{node.name}@#{node.host}")
    
    case :erlang.disconnect_node(node_name) do
      true ->
        update_node(node, %{status: "disconnected"})
        {:ok, node}
        
      false ->
        update_node(node, %{status: "error"})
        {:error, "Failed to disconnect from node"}
        
      :ignored ->
        {:error, "Disconnect ignored (node not connected)"}
    end
  end

  @doc """
  Gets the status of all connected Erlang nodes.
  """
  def get_connected_nodes do
    :erlang.nodes()
  end

  @doc """
  Checks if a node is currently connected.
  """
  def node_connected?(%Node{} = node) do
    if node.is_current do
      # Current node is always "connected"
      true
    else
      node_name = String.to_atom("#{node.name}@#{node.host}")
      node_name in :erlang.nodes()
    end
  end

  @doc """
  Updates node statuses based on actual connection status.
  """
  def refresh_node_statuses do
    nodes = list_nodes()
    connected_nodes = get_connected_nodes()
    
    Enum.each(nodes, fn node ->
      actual_status = if node.is_current do
        # Current node is always connected
        "connected"
      else
        node_name = String.to_atom("#{node.name}@#{node.host}")
        if node_name in connected_nodes, do: "connected", else: "disconnected"
      end
      
      if node.status != actual_status do
        update_node(node, %{status: actual_status})
      end
    end)
  end

  @doc """
  Creates the current ElixiHub node entry.
  """
  def ensure_current_node do
    current_node_name = :erlang.node() |> Atom.to_string()
    
    case get_current_node() do
      nil ->
        # Handle both distributed and non-distributed modes
        {name, host} = if current_node_name == "nonode@nohost" do
          {"elixihub", "localhost"}
        else
          case String.split(current_node_name, "@", parts: 2) do
            [name, host] -> {name, host}
            [name] -> {name, "localhost"}
          end
        end
        
        cookie = if current_node_name == "nonode@nohost" do
          "nocookie"
        else
          :erlang.get_cookie() |> Atom.to_string()
        end
        
        # Create the current node entry
        create_node(%{
          name: name,
          host: host,
          port: 4369, # Default EPMD port
          cookie: cookie,
          description: if current_node_name == "nonode@nohost" do
            "Current ElixiHub node (non-distributed mode)"
          else
            "Current ElixiHub node (distributed mode)"
          end,
          status: "connected",
          is_current: true
        })
      
      existing_node ->
        # Update existing current node info if needed
        # Make sure the current node status is correct
        if existing_node.status != "connected" do
          update_node(existing_node, %{status: "connected"})
        else
          {:ok, existing_node}
        end
    end
  end

  defp unset_all_current_nodes do
    from(n in Node, where: n.is_current == true)
    |> Repo.update_all(set: [is_current: false])
  end
end