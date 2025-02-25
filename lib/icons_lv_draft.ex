defmodule IconsLvDraft do
  @moduledoc """
  IconsLv is an SVG icon library for Phoenix LiveView applications.

  It provides a collection of SVG icons that can be easily customized and used
  in LiveView applications.
  """

  # Re-export the Icon and Categories modules for easier access
  defdelegate icon(assigns), to: IconsLvDraft.Icon

  @doc """
  Returns the version of the IconsLv library.
  """
  def version, do: Application.spec(:icons_lv_draft, :vsn)

  @doc """
  Initializes the IconsLv library.

  This function should be called during application startup to ensure
  that all icons are properly imported and available.
  """
  def init() do
    # Import Heroicons if they're available
    # if Code.ensure_loaded?(IconsLvDraft.Heroicons) do
    #   IconsLvDraft.Heroicons.import_heroicons()
    # end

    :ok
  end

  @doc """
  Generates the HTML code for an icon.

  This function returns the HTML code that can be copied and pasted into an HTML file.

  ## Examples

      IconsLv.generate_html_code("solid/check", base_color: "#000000")
      IconsLv.generate_html_code("outline/arrow", base_color: "#333", active_color: "#0066cc")

  ## Options

  * `:base_color` - The base color of the icon (default: "currentColor").
  * `:active_color` - The active color for interactive elements (default: nil).
  * `:warning_color` - The warning color for alert elements (default: nil).
  * `:class` - Additional CSS classes to add to the SVG element.
  """
  def generate_html_code(icon_name, opts \\ []) do
    base_color = Keyword.get(opts, :base_color, "currentColor")
    active_color = Keyword.get(opts, :active_color)
    warning_color = Keyword.get(opts, :warning_color)
    class = Keyword.get(opts, :class, "")

    [category, name] = String.split(icon_name, "/", parts: 2)
    icon_path = Application.app_dir(:icons_lv, "priv/static/icons/#{category}/#{name}.svg")

    svg_content = File.read!(icon_path)
    |> process_svg_for_html(base_color, active_color, warning_color, class)

    svg_content
  end

  @doc """
  Generates the LiveView code for an icon.

  This function returns the LiveView code that can be copied and pasted into a LiveView template.

  ## Examples

      IconsLv.generate_liveview_code("solid/check", base_color: "#000000")
      IconsLv.generate_liveview_code("outline/arrow", base_color: "#333", active_color: "#0066cc")

  ## Options

  * `:base_color` - The base color of the icon (default: "currentColor").
  * `:active_color` - The active color for interactive elements (default: nil).
  * `:warning_color` - The warning color for alert elements (default: nil).
  * `:class` - Additional CSS classes to add to the SVG element.
  """
  def generate_liveview_code(icon_name, opts \\ []) do
    base_color = Keyword.get(opts, :base_color, "currentColor")
    active_color = Keyword.get(opts, :active_color)
    warning_color = Keyword.get(opts, :warning_color)
    class = Keyword.get(opts, :class, "")

    active_color_attr = if active_color, do: " active_color=\"#{active_color}\"", else: ""
    warning_color_attr = if warning_color, do: " warning_color=\"#{warning_color}\"", else: ""
    class_attr = if class != "", do: " class=\"#{class}\"", else: ""

    ~s(<.icon name="#{icon_name}" base_color="#{base_color}"#{active_color_attr}#{warning_color_attr}#{class_attr} />)
  end

  # Private function to process SVG for HTML output
  defp process_svg_for_html(svg_content, base_color, active_color, warning_color, class) do
    # This is a simplified version - in a real implementation, use Floki for proper parsing
    svg_content = if class != "", do: add_class_to_svg(svg_content, class), else: svg_content

    svg_content
    |> String.replace("fill=\"currentColor\"", "fill=\"#{base_color}\"")
    |> add_color_variables_html(active_color, warning_color)
  end

  defp add_class_to_svg(svg_content, class) do
    # Simple regex-based approach - in a real app, use Floki
    if String.match?(svg_content, ~r/<svg[^>]*class="([^"]*)"/) do
      Regex.replace(~r/<svg([^>]*) class="([^"]*)"/, svg_content, "<svg\\1 class=\"\\2 #{class}\"")
    else
      Regex.replace(~r/<svg/, svg_content, "<svg class=\"#{class}\"")
    end
  end

  defp add_color_variables_html(svg, nil, nil), do: svg
  defp add_color_variables_html(svg, active_color, nil) do
    svg
    |> String.replace(
      "</svg>",
      "<style>:root { --active-color: #{active_color}; }</style></svg>"
    )
  end
  defp add_color_variables_html(svg, active_color, warning_color) do
    svg
    |> String.replace(
      "</svg>",
      "<style>:root { --active-color: #{active_color}; --warning-color: #{warning_color}; }</style></svg>"
    )
  end
end
