defmodule IconsLvDraft.SVGProcessor do
  @moduledoc """
  Process SVG files for the IconsLv library.

  This module provides functions for processing SVG files, including:
  - Reading SVG files from disk
  - Processing SVG content for color customization
  - Converting SVG paths to proper formats
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
    unique_id = if element_id, do: "#{element_id}-#{String.replace(icon_path, "/", "-")}", else: nil

    with [category, name] <- String.split(icon_path, "/", parts: 2),
         icon_file <- get_icon_path(category, name),
         {:ok, svg_content} <- File.read(icon_file) do

      # Check if the SVG has "currentColor"
      has_current_color = String.contains?(svg_content, "currentColor")

      # Process the SVG content
      svg_content = process_svg_content(svg_content, unique_id, base_color, active_color, warning_color, class, has_current_color)

      # Apply size if specified
      if size do
        svg_content
        |> ensure_width_height_attrs(size)
      else
        svg_content
      end
    else
      _ -> {:error, "Failed to process SVG file: #{icon_path}"}
    end
  end

  @doc """
  Extract the main fill color from an SVG.
  Returns the most common fill color or nil if no fill is found.
  """
  def extract_main_color(svg_content) when is_binary(svg_content) do
    # Look for fill attributes
    fill_pattern = ~r/fill=["']([^"']+)["']/i
    fill_colors = Regex.scan(fill_pattern, svg_content)
                  |> Enum.map(fn [_, color] -> color end)
                  |> Enum.reject(fn color -> color == "none" || color == "transparent" end)

    # Also look for fill in style tags
    style_pattern = ~r/style=["']([^"']*)fill:\s*([^;"']+)/i
    style_colors = Regex.scan(style_pattern, svg_content)
                   |> Enum.map(fn [_, _, color] -> color end)
                   |> Enum.reject(fn color -> color == "none" || color == "transparent" end)

    # Look for class definitions with fill
    class_fill_pattern = ~r/\.([^{]+){[^}]*fill:\s*([^;}]+)/i
    class_colors = Regex.scan(class_fill_pattern, svg_content)
                   |> Enum.map(fn [_, _, color] -> color end)
                   |> Enum.reject(fn color -> color == "none" || color == "transparent" end)

    # Combine all colors
    all_colors = fill_colors ++ style_colors ++ class_colors

    # Count occurrences of each color
    counts = Enum.reduce(all_colors, %{}, fn color, acc ->
      Map.update(acc, color, 1, &(&1 + 1))
    end)

    # Return the most common color or nil
    if Enum.empty?(counts) do
      nil
    else
      {color, _count} = Enum.max_by(counts, fn {_color, count} -> count end)
      color
    end
  end
  def extract_main_color(_), do: nil

  @doc """
  Ensure SVG has width and height attributes.

  ## Parameters
  - `svg_content` - The SVG content as a string
  - `size` - The size to set for width and height

  ## Returns
  - The SVG content with width and height attributes set
  """
  def ensure_width_height_attrs(svg_content, size) do
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
  - `has_current_color` - Whether the SVG uses currentColor (default: true)

  ## Returns
  - A string containing the processed SVG content
  """
  def process_svg_content(svg_content, element_id, base_color, active_color, warning_color, class, has_current_color \\ true) do
    # Extract the main color if we need to replace it
    main_color = if !has_current_color && base_color && base_color != "currentColor" do
      extract_main_color(svg_content)
    else
      nil
    end

    svg_content
    |> add_element_id(element_id)
    |> add_classes(class)
    |> set_base_color(base_color, main_color, has_current_color)
    |> add_color_variables(active_color, warning_color)
  end

  # Get the full path to an icon file
  defp get_icon_path(category, name) do
    Application.app_dir(:icons_lv_draft, "priv/static/icons/#{category}/#{name}.svg")
  end

  # Add an ID to the SVG element if not nil
  defp add_element_id(svg_content, nil), do: svg_content
  defp add_element_id(svg_content, element_id) do
    # Generate a truly unique ID by adding a random suffix
    unique_id = "#{element_id}-#{:rand.uniform(1000000)}"

    # First, collect all existing IDs within the SVG
    id_pattern = ~r/\sid="([^"]*)"/
    ids = Regex.scan(id_pattern, svg_content) |> Enum.map(fn [_, id] -> id end)

    # Create a map of old ID to new namespaced ID
    id_mapping = Enum.into(ids, %{}, fn old_id ->
      {old_id, "#{unique_id}-#{old_id}"}
    end)

    # Replace all IDs with namespaced versions
    svg_with_ids = Enum.reduce(id_mapping, svg_content, fn {old_id, new_id}, acc ->
      String.replace(acc, ~r/\sid="#{old_id}"/, " id=\"#{new_id}\"")
    end)

    # Replace internal references (url(#id)) with the new IDs
    svg_with_refs = Enum.reduce(id_mapping, svg_with_ids, fn {old_id, new_id}, acc ->
      String.replace(acc, ~r/url\(##{old_id}\)/, "url(##{new_id})")
    end)

    # Add ID to the SVG element if it doesn't have one
    if String.match?(svg_with_refs, ~r/<svg[^>]*id="[^"]*"/) do
      svg_with_refs
    else
      # Add the unique ID to the root SVG element
      Regex.replace(~r/<svg/, svg_with_refs, "<svg id=\"#{unique_id}\"")
    end
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
  defp set_base_color(svg_content, nil, _main_color, _has_current_color), do: svg_content
  defp set_base_color(svg_content, "currentColor", _main_color, _has_current_color), do: svg_content
  defp set_base_color(svg_content, base_color, main_color, has_current_color) do
    cond do
      # If SVG uses currentColor, replace it
      has_current_color ->
        svg_content
        |> String.replace(~r/fill="currentColor"/i, "fill=\"#{base_color}\"")
        |> String.replace(~r/stroke="currentColor"/i, "stroke=\"#{base_color}\"")

      # If we detected a main color, replace that specifically
      main_color != nil ->
        svg_content
        |> String.replace(~r/fill="#{main_color}"/i, "fill=\"#{base_color}\"")
        |> String.replace(~r/stroke="#{main_color}"/i, "stroke=\"#{base_color}\"")
        |> replace_in_style(main_color, base_color)

      # Otherwise, replace all fill colors except "none" and "transparent"
      true ->
        svg_content
        |> String.replace(~r/fill="([^"]*)"/i, fn match ->
          if String.contains?(match, "none") || String.contains?(match, "transparent") do
            match
          else
            "fill=\"#{base_color}\""
          end
        end)
    end
  end

  # Replace colors in style attributes
  defp replace_in_style(svg_content, from_color, to_color) do
    Regex.replace(~r/style="([^"]*)"/i, svg_content, fn _, style ->
      updated_style = style
        |> String.replace(~r/fill:\s*#{from_color}/i, "fill: #{to_color}")
        |> String.replace(~r/stroke:\s*#{from_color}/i, "stroke: #{to_color}")

      "style=\"#{updated_style}\""
    end)
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
