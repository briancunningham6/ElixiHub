defmodule ElixihubWeb.Admin.NodeLive.FormComponent do
  use ElixihubWeb, :live_component

  alias Elixihub.Nodes

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Configure connection details for the Elixir node</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="node-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Node Name" placeholder="myapp" />
        <.input field={@form[:host]} type="text" label="Host/IP Address" placeholder="192.168.1.100 or myhost.local" />
        <.input field={@form[:port]} type="number" label="Port" placeholder="4369" value={4369} />
        <.input field={@form[:cookie]} type="text" label="Erlang Cookie" placeholder="mycookie" />
        <.input field={@form[:description]} type="textarea" label="Description" placeholder="Describe this node..." />
        
        <%= unless @node.is_current do %>
          <.input 
            field={@form[:is_current]} 
            type="checkbox" 
            label="Mark as current node (only for the node running ElixiHub)" 
          />
        <% end %>
        
        <:actions>
          <.button phx-disable-with="Saving...">Save Node</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{node: node} = assigns, socket) do
    changeset = Nodes.change_node(node)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"node" => node_params}, socket) do
    changeset =
      socket.assigns.node
      |> Nodes.change_node(node_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"node" => node_params}, socket) do
    save_node(socket, socket.assigns.action, node_params)
  end

  defp save_node(socket, :edit, node_params) do
    case Nodes.update_node(socket.assigns.node, node_params) do
      {:ok, node} ->
        notify_parent({:saved, node})

        {:noreply,
         socket
         |> put_flash(:info, "Node updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_node(socket, :new, node_params) do
    case Nodes.create_node(node_params) do
      {:ok, node} ->
        notify_parent({:saved, node})

        {:noreply,
         socket
         |> put_flash(:info, "Node created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end