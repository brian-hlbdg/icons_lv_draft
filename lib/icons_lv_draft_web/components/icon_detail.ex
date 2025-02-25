defmodule IconsLvDraftWeb.IconDetail do
  @moduledoc """
  Component for displaying detailed information about an icon.
  """
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  import IconsLvDraftWeb.CoreComponents

  @doc """
  Renders a modal with detailed information about an icon.

  ## Examples

      <.icon_detail
        id="icon-detail"
        icon_path="solid/check"
        base_color="#000000"
        active_color="#0066cc"
        warning_color="#ff0000"
        show={@show_detail}
      />

  ## Attributes

  * `id` - The ID of the modal (required).
  * `icon_path` - The path of the icon (category/name) (required).
  * `base_color` - The base color of the icon (default: "currentColor").
  * `active_color` - The active color of the icon (default: nil).
  * `warning_color` - The warning color of the icon (default: nil).
  * `show` - Whether to show the modal (default: false).
  """
  attr :id, :string, required: true
  attr :icon_path, :string, required: true
  attr :base_color, :string, default: "currentColor"
  attr :active_color, :string, default: nil
  attr :warning_color, :string, default: nil
  attr :show, :boolean, default: false

  def icon_detail(assigns) do
    # Split the icon path into category and name
    [category, name] = String.split(assigns.icon_path, "/", parts: 2)

    # Generate HTML and LiveView code
    html_code = IconsLvDraft.generate_html_code(assigns.icon_path,
      base_color: assigns.base_color,
      active_color: assigns.active_color,
      warning_color: assigns.warning_color
    )

    liveview_code = IconsLvDraft.generate_liveview_code(assigns.icon_path,
      base_color: assigns.base_color,
      active_color: assigns.active_color,
      warning_color: assigns.warning_color
    )

    # Get the formatted name
    formatted_name = IconsLvDraft.Categories.format_name(name)

    assigns = assigns
      |> assign(:category, category)
      |> assign(:name, name)
      |> assign(:formatted_name, formatted_name)
      |> assign(:html_code, html_code)
      |> assign(:liveview_code, liveview_code)

    ~H"""
    <div
      id={@id}
      class="phx-modal"
      phx-remove={JS.hide(transition: "fade-out")}
      phx-capture-click="close_detail"
      style={if @show, do: "display: flex;", else: "display: none;"}
    >
      <div
        class="phx-modal-content bg-white rounded-lg shadow-lg max-w-2xl w-full"
        phx-click-away={JS.dispatch("click", to: "#close-modal")}
        phx-window-keydown={JS.dispatch("click", to: "#close-modal")}
        phx-key="escape"
      >
        <div class="p-6">
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-xl font-semibold"><%= @formatted_name %> Icon</h2>
            <button
              id="close-modal"
              phx-click="close_detail"
              class="text-gray-500 hover:text-gray-700"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <div class="mb-6 flex justify-center items-center p-8 border rounded-lg">
            <.icon name={@icon_path} base_color={@base_color} active_color={@active_color} warning_color={@warning_color} class="w-16 h-16" />
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <h3 class="text-lg font-medium mb-2">HTML Code</h3>
              <div class="bg-gray-50 p-4 rounded-lg overflow-x-auto">
                <pre class="text-sm"><code><%= @html_code %></code></pre>
              </div>
              <button
                phx-click={JS.dispatch("icons-lv:copy", detail: %{text: @html_code})}
                class="mt-2 px-3 py-1 bg-gray-200 hover:bg-gray-300 rounded text-sm"
              >
                Copy HTML Code
              </button>
            </div>

            <div>
              <h3 class="text-lg font-medium mb-2">LiveView Code</h3>
              <div class="bg-gray-50 p-4 rounded-lg overflow-x-auto">
                <pre class="text-sm"><code><%= @liveview_code %></code></pre>
              </div>
              <button
                phx-click={JS.dispatch("icons-lv:copy", detail: %{text: @liveview_code})}
                class="mt-2 px-3 py-1 bg-gray-200 hover:bg-gray-300 rounded text-sm"
              >
                Copy LiveView Code
              </button>
            </div>
          </div>

          <div class="mt-6">
            <h3 class="text-lg font-medium mb-2">Details</h3>
            <table class="w-full text-sm">
              <tbody>
                <tr>
                  <td class="py-1 font-medium">Category:</td>
                  <td><%= @category %></td>
                </tr>
                <tr>
                  <td class="py-1 font-medium">Name:</td>
                  <td><%= @name %></td>
                </tr>
                <tr>
                  <td class="py-1 font-medium">Base Color:</td>
                  <td><code><%= @base_color %></code></td>
                </tr>
                <%= if @active_color do %>
                  <tr>
                    <td class="py-1 font-medium">Active Color:</td>
                    <td><code><%= @active_color %></code></td>
                  </tr>
                <% end %>
                <%= if @warning_color do %>
                  <tr>
                    <td class="py-1 font-medium">Warning Color:</td>
                    <td><code><%= @warning_color %></code></td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
