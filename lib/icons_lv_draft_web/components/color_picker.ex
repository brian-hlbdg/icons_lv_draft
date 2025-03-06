defmodule IconsLvDraftWeb.Components.ColorPicker do
  @moduledoc """
  A color picker component for the IconsLvDraft application.
  """
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  attr :id, :string, required: true, doc: "Unique ID for the color picker"
  attr :value, :string, doc: "The current color value"
  attr :label, :string, default: "Color", doc: "The label for the color picker"
  attr :color_type, :string, required: true, doc: "Type of color (base, active, warning)"
  attr :on_change, JS, default: %JS{}, doc: "JS command to execute on color change"
  attr :disabled, :boolean, default: false, doc: "Whether the color picker is disabled"
  attr :placeholder, :string, default: "", doc: "Placeholder text for the text input"

  def color_picker(assigns) do
    ~H"""
    <div class="color-picker-container" id={"color-picker-#{@id}"} phx-hook="ColorPicker">
      <label for={@id} class="block text-sm font-medium text-gray-700 mb-1"><%= @label %></label>
      <div class="flex">
        <div class="relative flex items-center">
          <input
            type="color"
            id={"color-" <> @id}
            value={@value && String.match?(@value, ~r/^#[0-9A-F]{6}$/i) && @value || "#000000"}
            class="sr-only"
            disabled={@disabled}
            phx-value-color={@color_type}
          />
          <div
            class="w-8 h-8 rounded-l border border-gray-300 flex items-center justify-center cursor-pointer overflow-hidden"
            phx-click={JS.dispatch("click", to: "#color-#{@id}")}
            style={"background-color: #{(@value && @value != "currentColor") && @value || "#ffffff"}"}
          >
            <div class="color-swatch"></div>
          </div>
          <input
            type="text"
            id={@id}
            value={@value}
            placeholder={@placeholder}
            class="w-full rounded-r px-3 py-2 border border-l-0 border-gray-300"
            phx-change="update-color"
            phx-value-color={@color_type}
            disabled={@disabled}
            name={"color-#{@color_type}"}
          />
        </div>
      </div>
    </div>
    """
  end
end
