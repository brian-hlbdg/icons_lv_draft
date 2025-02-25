defmodule IconsLvDraft.Icon do
  use Phoenix.Component
  import Phoenix.HTML, only: [raw: 1]  # This is important!

  attr :name, :string, required: true
  attr :class, :string, default: nil
  attr :base_color, :string, default: "currentColor"
  attr :active_color, :string, default: nil
  attr :warning_color, :string, default: nil
  attr :rest, :global, include: ~w(aria-hidden aria-label)

  def icon(assigns) do
    parts = String.split(assigns.name, "/", parts: 2)

    assigns = if length(parts) == 2 do
      [category, icon_name] = parts
      icon_path = Application.app_dir(:icons_lv_draft, "priv/static/icons/#{category}/#{icon_name}.svg")

      case File.read(icon_path) do
        {:ok, svg_contents} ->
          assigns
          |> assign(:svg_contents, svg_contents)
          |> assign(:category, category)
          |> assign(:icon_name, icon_name)
          |> assign(:error, nil)

        {:error, reason} ->
          assigns
          |> assign(:error, "Icon not found: #{assigns.name} (#{reason})")
          |> assign(:category, category)
          |> assign(:icon_name, icon_name)
      end
    else
      assigns
      |> assign(:error, "Invalid icon name format: #{assigns.name}. Should be 'category/name'.")
    end

    ~H"""
    <%= if @error do %>
      <div class="icon-error text-red-500 text-sm" title={@error}>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class={@class || "w-5 h-5"}>
          <path fill-rule="evenodd" d="M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zm-1.72 6.97a.75.75 0 10-1.06 1.06L10.94 12l-1.72 1.72a.75.75 0 101.06 1.06L12 13.06l1.72 1.72a.75.75 0 101.06-1.06L13.06 12l1.72-1.72a.75.75 0 10-1.06-1.06L12 10.94l-1.72-1.72z" clip-rule="evenodd" />
        </svg>
      </div>
    <% else %>
      <div
        id={"icon-wrapper-#{@icon_name}"}
        class={"icon-wrapper #{@class}"}
        title="Click to copy icon code"
      >
        <%= raw(process_svg(@svg_contents, @base_color, @active_color, @warning_color)) %>
      </div>
    <% end %>
    """
  end

  def process_svg(svg_content, base_color, active_color, warning_color) do
    # Basic implementation - in a real app, use Floki for proper parsing
    svg_content
    |> String.replace("fill=\"currentColor\"", "fill=\"#{base_color}\"")
    |> add_color_variables(active_color, warning_color)
  end

  defp add_color_variables(svg, nil, nil), do: svg
  defp add_color_variables(svg, active_color, nil) do
    svg
    |> String.replace(
      "</svg>",
      "<style>:root { --active-color: #{active_color}; }</style></svg>"
    )
  end
  defp add_color_variables(svg, active_color, warning_color) do
    svg
    |> String.replace(
      "</svg>",
      "<style>:root { --active-color: #{active_color}; --warning-color: #{warning_color}; }</style></svg>"
    )
  end
end
