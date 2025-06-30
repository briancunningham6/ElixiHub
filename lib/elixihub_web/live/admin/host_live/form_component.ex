defmodule ElixihubWeb.Admin.HostLive.FormComponent do
  use ElixihubWeb, :live_component

  alias Elixihub.Hosts

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Configure deployment host information</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="host-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Host Name" placeholder="Production Server" />
        <.input field={@form[:ip_address]} type="text" label="IP Address" placeholder="192.168.1.100" />
        <.input field={@form[:ssh_username]} type="text" label="SSH Username" placeholder="ubuntu" />
        <.input field={@form[:ssh_password]} type="password" label="SSH Password (optional)" />
        <.input field={@form[:ssh_port]} type="number" label="SSH Port" value="22" />
        <.input field={@form[:description]} type="textarea" label="Description" placeholder="Description of this host..." />
        
        <div class="bg-yellow-50 border border-yellow-200 rounded-md p-4">
          <div class="flex">
            <div class="ml-3">
              <h3 class="text-sm font-medium text-yellow-800">
                Security Note
              </h3>
              <div class="mt-2 text-sm text-yellow-700">
                <p>SSH passwords are stored encrypted. For production use, consider using SSH key authentication instead.</p>
              </div>
            </div>
          </div>
        </div>
        
        <:actions>
          <.button phx-disable-with="Saving...">Save Host</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{host: host} = assigns, socket) do
    changeset = Hosts.change_host(host)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"host" => host_params}, socket) do
    changeset =
      socket.assigns.host
      |> Hosts.change_host(host_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"host" => host_params}, socket) do
    save_host(socket, socket.assigns.action, host_params)
  end

  defp save_host(socket, :edit, host_params) do
    case Hosts.update_host(socket.assigns.host, host_params) do
      {:ok, host} ->
        notify_parent({:saved, host})

        {:noreply,
         socket
         |> put_flash(:info, "Host updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_host(socket, :new, host_params) do
    case Hosts.create_host(host_params) do
      {:ok, host} ->
        notify_parent({:saved, host})

        {:noreply,
         socket
         |> put_flash(:info, "Host created successfully")
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