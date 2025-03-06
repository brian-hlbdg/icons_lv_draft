defmodule IconsLvDraftWeb.IconPreviewHelpers do
  @moduledoc """
  Helper functions for rendering a single SVG icon preview.
  """

  @doc """
  Renders a direct SVG preview for a single icon.

  Instead of using the icon component which may include multiple icons,
  this directly reads the SVG file and renders it with the specified colors.
  """
  def render_single_icon_preview(icon_path, base_color, active_color, warning_color) do
    try do
      # Parse the category and name from the path
      [category, name] = String.split(icon_path, "/", parts: 2)
      file_path = Application.app_dir(:icons_lv_draft, "priv/static/icons/#{category}/#{name}.svg")

      # Read the SVG content directly
      svg_content = File.read!(file_path)

      # Apply colors to the SVG
      svg_content = apply_colors(svg_content, base_color, active_color, warning_color)

      # Return the SVG content
      {:ok, svg_content}
    rescue
      e ->
        {:error, "Failed to render icon: #{Exception.message(e)}"}
    end
  end

  defp apply_colors(svg_content, base_color, active_color, warning_color) do
    # Replace the currentColor with the base color
    svg_content = if base_color, do: String.replace(svg_content, "currentColor", base_color), else: svg_content

    # Add additional color variables if needed
    svg_with_vars = if active_color || warning_color do
      # Extract closing svg tag to add styles before it
      [content, closing] =
        case Regex.run(~r/(.*?)(<\/svg>)$/, svg_content, capture: :all_but_first) do
          [content, closing] -> [content, closing]
          _ -> [svg_content, ""]
        end

      # Build style tag with variables
      style_tag = "<style>:root {"
      style_tag = if active_color, do: style_tag <> " --active-color: #{active_color};", else: style_tag
      style_tag = if warning_color, do: style_tag <> " --warning-color: #{warning_color};", else: style_tag
      style_tag = style_tag <> " }</style>"

      # Insert style before closing svg tag
      content <> style_tag <> closing
    else
      svg_content
    end

    # Ensure proper sizing
    svg_with_vars
    |> add_width_height_if_missing()
  end

  defp add_width_height_if_missing(svg_content) do
    if !String.contains?(svg_content, "width=") || !String.contains?(svg_content, "height=") do
      # Add width/height attributes to the svg tag if they're missing
      String.replace(svg_content, ~r/<svg/, "<svg width=\"100%\" height=\"100%\"", global: false)
    else
      svg_content
    end
  end
end
