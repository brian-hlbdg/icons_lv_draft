defmodule IconsLvDraft.SVGProcessor do
  @moduledoc """
  Process SVG files for the IconsLv library.

  This module provides functions for processing SVG files, including:
  - Reading SVG files from disk
  - Processing SVG content for color customization
  - Converting SVG paths to proper formats
  - Validating SVG compatibility with customization
  """

  @doc """
  Process an SVG file with the given path and options.

  ## Parameters
  - `icon_path` - The path to the icon (category/name)
  - `element_id` - The ID prefix to assign to the SVG element (optional)
  - `opts` - A keyword list of options:
    - `:base_color` - The base color for the SVG (default: "currentColor")
    - `:active_color` - The active color for interactive elements (default: nil)
    - `:warning_color` - The warning color for alert elements (default: nil)
    - `:class` - Additional CSS classes to add to the SVG element (default: "")
    - `:size` - Size to set for width and height if needed (default: nil)

  ## Returns
  - A string containing the processed SVG content
  - `:error` tuple if the file cannot be read or processed
  """
  def process_svg_file(icon_path, element_id, opts \\ []) do
    base_color = Keyword.get(opts, :base_color, "currentColor")
    active_color = Keyword.get(opts, :active_color)
    warning_color = Keyword.get(opts, :warning_color)
    class = Keyword.get(opts, :class, "")
    size = Keyword.get(opts, :size)

    # Create a unique ID by combining the element_id with the icon path
    # This ensures we don't have ID conflicts when showing multiple icons
    unique_id = if element_id, do: "#{element_id}-#{String.replace(icon_path, "/", "-")}", else: nil

    with [category, name] <- String.split(icon_path, "/", parts: 2),
         icon_file <- get_icon_path(category, name),
         {:ok, svg_content} <- File.read(icon_file) do

      # Check if the SVG can be colored
      if !supports_color_customization?(svg_content) &&
         (base_color != "currentColor" || active_color || warning_color) do
        {:error, "This SVG doesn't support color customization"}
      else
        svg_content = process_svg_content(svg_content, unique_id, base_color, active_color, warning_color, class)

        # Apply size if specified
        if size do
          svg_content
          |> ensure_width_height_attrs(size)
        else
          svg_content
        end
      end
    else
      _ -> {:error, "Failed to process SVG file: #{icon_path}"}
    end
  end


  @doc """
  Check if an SVG supports color customization.
  Returns true if the SVG contains fillable paths, stroke attributes,
  or uses currentColor that can be customized.
  """
def supports_color_customization?(svg_content) do
  # Check for various color-related attributes
  has_fill = String.match?(svg_content, ~r/fill=["']([^"']+)["']/)
  has_stroke = String.match?(svg_content, ~r/stroke=["']([^"']+)["']/)
  has_style = String.match?(svg_content, ~r/<style[^>]*>/)
  has_current_color = String.contains?(svg_content, "currentColor")

  # SVG can be customized if it has any of these attributes
  has_fill || has_stroke || has_style || has_current_color
end

  # Helper function to ensure width and height attributes are set
  defp ensure_width_height_attrs(svg_content, size) do
    # Replace or add width and height attributes
    svg_content = Regex.replace(~r/(<svg[^>]*)(width="[^"]*")/, svg_content, "\\1width=\"#{size}\"")
    svg_content = Regex.replace(~r/(<svg[^>]*)(height="[^"]*")/, svg_content, "\\1height=\"#{size}\"")

    # If no width attribute exists, add it
    svg_content = if !String.match?(svg_content, ~r/<svg[^>]*width=/) do
      Regex.replace(~r/<svg/, svg_content, "<svg width=\"#{size}\"")
    else
      svg_content
    end

    # If no height attribute exists, add it
    svg_content = if !String.match?(svg_content, ~r/<svg[^>]*height=/) do
      Regex.replace(~r/<svg/, svg_content, "<svg height=\"#{size}\"")
    else
      svg_content
    end

    svg_content
  end

  @doc """
  Process raw SVG content with customizations.

  ## Parameters
  - `svg_content` - The raw SVG content as a string
  - `element_id` - The ID to assign to the SVG element (optional)
  - `base_color` - The base color for the SVG
  - `active_color` - The active color for interactive elements (optional)
  - `warning_color` - The warning color for alert elements (optional)
  - `class` - Additional CSS classes to add to the SVG element

  ## Returns
  - A string containing the processed SVG content
  """
  def process_svg_content(svg_content, element_id, base_color, active_color, warning_color, class) do
    svg_content
    |> add_element_id(element_id)
    |> add_classes(class)
    |> set_base_color(base_color)
    |> add_color_variables(active_color, warning_color)
  end

  # Get the full path to an icon file
  defp get_icon_path(category, name) do
    Application.app_dir(:icons_lv_draft, "priv/static/icons/#{category}/#{name}.svg")
  end

  # Add an ID to the SVG element if not nil
  defp add_element_id(svg_content, nil), do: svg_content
  defp add_element_id(svg_content, element_id) do
    # First, remove any existing IDs from all elements inside the SVG to avoid ID conflicts
    svg_content = Regex.replace(~r/(<[^>]*)id="[^"]*"([^>]*)/, svg_content, "\\1\\2")

    # Generate a unique ID for the SVG element
    unique_id = "#{element_id}-#{:erlang.system_time(:millisecond)}"

    # Add the unique ID to the SVG root element
    svg_content = if String.match?(svg_content, ~r/<svg/) do
      Regex.replace(~r/<svg/, svg_content, "<svg id=\"#{unique_id}\"")
    else
      svg_content
    end

    # Fix any internal references that might have relied on old IDs
    # In a real app, you would need more sophisticated handling here
    svg_content
  end

  # Add CSS classes to the SVG element
  defp add_classes(svg_content, ""), do: svg_content
  defp add_classes(svg_content, class) do
    if String.match?(svg_content, ~r/<svg[^>]*class="([^"]*)"/) do
      Regex.replace(~r/<svg([^>]*)class="([^"]*)"/, svg_content, "<svg\\1class=\"\\2 #{class}\"")
    else
      Regex.replace(~r/<svg/, svg_content, "<svg class=\"#{class}\"")
    end
  end

  # Set the base color of the SVG
  defp set_base_color(svg_content, "currentColor"), do: svg_content
  defp set_base_color(svg_content, base_color) do
    svg_content
    |> String.replace("fill=\"currentColor\"", "fill=\"#{base_color}\"")
    |> String.replace("stroke=\"currentColor\"", "stroke=\"#{base_color}\"")
  end

  # Add color variables for active and warning states
  defp add_color_variables(svg, nil, nil), do: svg
  defp add_color_variables(svg, active_color, nil) do
    svg
    |> String.replace(
      "</svg>",
      "<style>:root { --active-color: #{active_color}; }</style></svg>"
    )
  end
  defp add_color_variables(svg, nil, warning_color) do
    svg
    |> String.replace(
      "</svg>",
      "<style>:root { --warning-color: #{warning_color}; }</style></svg>"
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
