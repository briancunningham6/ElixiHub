defmodule TaskManagerWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.
  """
  use Phoenix.Component
  use Phoenix.HTML
  
  import Phoenix.LiveView.JS
  alias Phoenix.LiveView.JS

  @doc """
  Renders a button.
  """
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(type form name value disabled)
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      class={[
        "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500",
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Renders a badge.
  """
  attr :color, :string, default: "gray"
  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
      badge_color(@color)
    ]}>
      <%= render_slot(@inner_block) %>
    </span>
    """
  end

  defp badge_color("gray"), do: "bg-gray-100 text-gray-800"
  defp badge_color("red"), do: "bg-red-100 text-red-800"
  defp badge_color("yellow"), do: "bg-yellow-100 text-yellow-800"
  defp badge_color("green"), do: "bg-green-100 text-green-800"
  defp badge_color("blue"), do: "bg-blue-100 text-blue-800"
  defp badge_color("indigo"), do: "bg-indigo-100 text-indigo-800"
  defp badge_color("purple"), do: "bg-purple-100 text-purple-800"
  defp badge_color("pink"), do: "bg-pink-100 text-pink-800"
  defp badge_color(_), do: "bg-gray-100 text-gray-800"

  @doc """
  Renders a header with title and actions.
  """
  attr :class, :string, default: ""

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={["mb-6", @class]}>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-bold text-gray-900">
            <%= render_slot(@inner_block) %>
          </h1>
          <%= for subtitle <- @subtitle do %>
            <p class="mt-2 text-sm text-gray-600">
              <%= render_slot(subtitle) %>
            </p>
          <% end %>
        </div>
        <div class="flex items-center space-x-4">
          <%= for action <- @actions do %>
            <%= render_slot(action) %>
          <% end %>
        </div>
      </div>
    </header>
    """
  end

  @doc """
  Renders a table.
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
      <table class="min-w-full divide-y divide-gray-300">
        <thead class="bg-gray-50">
          <tr>
            <%= for col <- @col do %>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                <%= col[:label] %>
              </th>
            <% end %>
            <th :if={@action != []} scope="col" class="relative px-6 py-3">
              <span class="sr-only">Actions</span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream" || "replace"}
          class="bg-white divide-y divide-gray-200"
        >
          <%= for row <- @rows do %>
            <tr id={@row_id && @row_id.(row)} class="hover:bg-gray-50">
              <%= for {col, i} <- Enum.with_index(@col) do %>
                <td
                  phx-click={@row_click && @row_click.(row)}
                  class={["px-6 py-4 whitespace-nowrap text-sm", @row_click && "cursor-pointer"]}
                >
                  <%= render_slot(col, row) %>
                </td>
              <% end %>
              <td :if={@action != []} class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <%= for action <- @action do %>
                  <%= render_slot(action, row) %>
                <% end %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end


  @doc """
  Renders a simple form.
  """
  attr :for, :any, required: true, doc: "the datastructure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class="space-y-6">
        <%= render_slot(@inner_block, f) %>
        <%= for action <- @actions do %>
          <div class="flex items-center justify-end space-x-4">
            <%= render_slot(action, f) %>
          </div>
        <% end %>
      </div>
    </.form>
    """
  end

  @doc """
  Renders an input.
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
               range radio search tel text textarea time url week select)

  attr :field, :any,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  slot :inner_block

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div>
      <label for={@id} class="block text-sm font-medium text-gray-700"><%= @label %></label>
      <select
        id={@id}
        name={@name}
        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value=""><%= @prompt %></option>
        <%= for {label, value} <- @options do %>
          <option value={value} selected={@value == value}><%= label %></option>
        <% end %>
      </select>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div>
      <label for={@id} class="block text-sm font-medium text-gray-700"><%= @label %></label>
      <textarea
        id={@id}
        name={@name}
        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
        {@rest}
      ><%= @value %></textarea>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div>
      <label for={@id} class="block text-sm font-medium text-gray-700"><%= @label %></label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={@value}
        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
        {@rest}
      />
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end


  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-2 text-sm text-red-600">
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  @doc """
  Renders a modal.
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && "show"}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div class="fixed inset-0 bg-black bg-opacity-50 transition-opacity" />
      <div class="fixed inset-0 overflow-y-auto">
        <div class="flex min-h-full items-center justify-center p-4">
          <div class="relative bg-white rounded-lg p-6 shadow-xl">
            <%= render_slot(@inner_block) %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(to: "##{id}")
  end

  def show_modal(js \\ %JS{}, id) do
    js
    |> JS.show(to: "##{id}")
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
  
  defp get_field_errors(%Ecto.Changeset{} = changeset, field_name) do
    changeset.errors
    |> Enum.filter(fn {field, _} -> field == field_name end)
    |> Enum.map(fn {_, error} -> translate_error(error) end)
  end
  
  defp get_field_errors(_, _), do: []
  
  defp get_field_value(%Ecto.Changeset{} = changeset, field_name) do
    Ecto.Changeset.get_field(changeset, field_name)
  end
  
  defp get_field_value(_, _), do: nil


  @doc """
  Renders flash messages.
  """
  attr :flash, :map, default: %{}
  attr :id, :string, default: "flash"

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash kind={:info} title="Info" flash={@flash} />
      <.flash kind={:error} title="Error" flash={@flash} />
    </div>
    """
  end

  @doc """
  Renders a single flash message.
  """
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :title, :string, doc: "the title of the flash message"
  attr :flash, :map, default: %{}, doc: "the map of flash messages"

  def flash(assigns) do
    ~H"""
    <div
      :if={msg = Phoenix.Flash.get(@flash, @kind)}
      class={[
        "rounded-md p-4 mb-4",
        @kind == :info && "bg-blue-50 text-blue-800",
        @kind == :error && "bg-red-50 text-red-800"
      ]}
    >
      <div class="flex">
        <div class="ml-3">
          <h3 class="text-sm font-medium">
            <%= @title %>
          </h3>
          <div class="mt-2 text-sm">
            <p><%= msg %></p>
          </div>
        </div>
      </div>
    </div>
    """
  end


end