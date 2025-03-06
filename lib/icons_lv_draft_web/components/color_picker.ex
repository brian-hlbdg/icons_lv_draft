defmodule IconsLvDraftWeb.Components.ColorPicker do
  @moduledoc """
  A color picker component that provides a text input with a color preview.
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :value, :string, default: nil
  attr :label, :string, required: true
  attr :placeholder, :string, default: "e.g., #000000, currentColor"
  attr :phx_change, :string, default: nil
  attr :phx_value_color, :string, default: nil
  attr :required, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :help_text, :string, default: nil

  def color_picker(assigns) do
    # Handle the case where value is nil for the preview
    preview_color = case assigns.value do
      nil -> "#cccccc"  # Default gray if no color is selected
      "currentColor" -> "#000000"  # Black for currentColor
      "" -> "#cccccc"  # Gray for empty string
      color -> color   # Use the actual color value
    end

    assigns = assign(assigns, :preview_color, preview_color)

    ~H"""
    <div>
      <label for={@id} class="block text-sm font-medium text-gray-700 mb-1">
        <%= @label %><%= if @required, do: " *" %>
      </label>
      <div class="flex">
        <input
          type="text"
          id={@id}
          name={@name}
          value={@value}
          placeholder={@placeholder}
          disabled={@disabled}
          required={@required}
          phx-change={@phx_change}
          phx-value-color={@phx_value_color}
          class={"w-full px-3 py-2 border border-gray-300 rounded-l-md #{if @disabled, do: "bg-gray-100 text-gray-500"}"}
        />
        <div
          class={"w-10 border-t border-r border-b border-gray-300 rounded-r-md flex items-center justify-center #{if @disabled, do: "bg-gray-100"}"}
          style={"background-color: #{@preview_color};"}
        >
        </div>
      </div>
      <%= if @help_text do %>
        <div class="text-xs text-gray-500 mt-1"><%= @help_text %></div>
      <% end %>
    </div>
    """
  end
end
