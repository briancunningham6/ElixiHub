defmodule ElixihubWeb.Admin.AppLive.FormComponent do
  use ElixihubWeb, :live_component

  alias Elixihub.Apps
  alias Elixihub.Nodes

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Register or edit application information</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="app-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Application Name" />
        <.input field={@form[:description]} type="textarea" label="Description" />
        <.input field={@form[:url]} type="text" label="Application URL" placeholder="https://example.com" />
        <.input 
          field={@form[:status]} 
          type="select" 
          label="Status" 
          options={[{"Active", "active"}, {"Inactive", "inactive"}, {"Pending", "pending"}]}
        />
        <.input 
          field={@form[:node_id]} 
          type="select" 
          label="Deployment Node" 
          prompt="Select a node (optional)"
          options={@node_options}
        />
        
        <%= if @action == :edit do %>
          <div class="mt-4 p-4 bg-gray-50 rounded-lg">
            <h4 class="text-sm font-medium text-gray-900 mb-2">API Key</h4>
            <div class="text-sm text-gray-600">
              <code class="bg-white px-2 py-1 rounded border"><%= @app.api_key %></code>
            </div>
            <p class="text-xs text-gray-500 mt-1">
              The API key cannot be changed. If compromised, delete and recreate the application.
            </p>
          </div>
        <% end %>
        
        <:actions>
          <.button phx-disable-with="Saving...">Save Application</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{app: app} = assigns, socket) do
    changeset = Apps.change_app(app)
    node_options = get_node_options()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:node_options, node_options)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"app" => app_params}, socket) do
    changeset =
      socket.assigns.app
      |> Apps.change_app(app_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"app" => app_params}, socket) do
    save_app(socket, socket.assigns.action, app_params)
  end

  defp save_app(socket, :edit, app_params) do
    case Apps.update_app(socket.assigns.app, app_params) do
      {:ok, app} ->
        notify_parent({:saved, app})

        {:noreply,
         socket
         |> put_flash(:info, "Application updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_app(socket, :new, app_params) do
    case Apps.create_app(app_params) do
      {:ok, app} ->
        notify_parent({:saved, app})

        {:noreply,
         socket
         |> put_flash(:info, "Application registered successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
  
  defp get_node_options do
    Nodes.list_nodes()
    |> Enum.map(fn node ->
      label = "#{node.name}@#{node.host}"
      label = if node.is_current, do: "#{label} (Current)", else: label
      {label, node.id}
    end)
  end
end