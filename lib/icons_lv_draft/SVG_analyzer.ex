defmodule IconsLvDraft.SVGAnalyzer do
  @moduledoc """
  Analyzes and standardizes SVG files according to modern best practices.

  This module provides functionality to:
  - Parse SVG content
  - Analyze SVG structure and elements
  - Convert outdated elements (g, polygon, rect, etc.) to path elements
  - Optimize the SVG for modern usage
  - Generate a summary of changes made
  """

  @doc """
  Analyzes an SVG file and returns a report of its structure.

  ## Parameters
  - `svg_content` - The SVG content as a binary string

  ## Returns
  A map containing analysis information:
  - `:elements` - Count of each element type
  - `:attributes` - List of attributes used
  - `:size` - File size information
  - `:viewbox` - The viewBox attribute if present
  - `:issues` - Any potential issues found
  """
  def analyze_svg(svg_content) when is_binary(svg_content) do
    # Parse the SVG using SweetXml
    try do
      # Count elements
      element_counts = %{
        "svg" => count_elements(svg_content, "svg"),
        "path" => count_elements(svg_content, "path"),
        "g" => count_elements(svg_content, "g"),
        "circle" => count_elements(svg_content, "circle"),
        "rect" => count_elements(svg_content, "rect"),
        "polygon" => count_elements(svg_content, "polygon"),
        "polyline" => count_elements(svg_content, "polyline"),
        "line" => count_elements(svg_content, "line"),
        "ellipse" => count_elements(svg_content, "ellipse"),
        "text" => count_elements(svg_content, "text"),
        "style" => count_elements(svg_content, "style"),
        "defs" => count_elements(svg_content, "defs")
      }

      # Extract attributes from SVG tag
      svg_attrs = extract_svg_attributes(svg_content)

      # Get file size
      size_info = %{
        "original_bytes" => byte_size(svg_content),
        "original_readable" => format_file_size(byte_size(svg_content))
      }

      # Identify issues
      issues = identify_svg_issues(svg_content, element_counts, svg_attrs)

      %{
        elements: element_counts,
        attributes: svg_attrs,
        size: size_info,
        viewbox: svg_attrs["viewBox"],
        issues: issues
      }
    rescue
      e -> %{
        error: "Failed to analyze SVG: #{Exception.message(e)}",
        elements: %{},
        attributes: %{},
        size: %{},
        viewbox: nil,
        issues: ["Invalid SVG format"]
      }
    end
  end

  @doc """
  Standardizes an SVG according to modern best practices.

  ## Parameters
  - `svg_content` - The original SVG content as a binary string

  ## Returns
  A map containing:
  - `:optimized_svg` - The standardized SVG content
  - `:changes` - List of changes made
  - `:original_size` - Original file size in bytes
  - `:optimized_size` - New file size in bytes
  - `:size_reduction` - Percentage reduction in file size
  """
  def standardize_svg(svg_content) when is_binary(svg_content) do
    original_size = byte_size(svg_content)
    changes = []

    # 1. Convert standalone style elements to inline styles
    {svg_content, style_changes} = process_style_elements(svg_content)
    changes = changes ++ style_changes

    # 2. Convert groups (g elements) when possible
    {svg_content, group_changes} = process_groups(svg_content)
    changes = changes ++ group_changes

    # 3. Convert basic shapes to path elements
    {svg_content, shape_changes} = convert_shapes_to_paths(svg_content)
    changes = changes ++ shape_changes

    # 4. Clean up unnecessary attributes
    {svg_content, attr_changes} = clean_attributes(svg_content)
    changes = changes ++ attr_changes

    # 5. Ensure viewBox is present
    {svg_content, viewbox_changes} = ensure_viewbox(svg_content)
    changes = changes ++ viewbox_changes

    # 6. Clean up unnecessary whitespace
    svg_content = String.trim(svg_content)

    optimized_size = byte_size(svg_content)
    size_reduction =
      if original_size > 0 do
        ((original_size - optimized_size) / original_size * 100)
        |> Float.round(2)
      else
        0.0
      end

    %{
      optimized_svg: svg_content,
      changes: changes,
      original_size: original_size,
      optimized_size: optimized_size,
      size_reduction: size_reduction
    }
  end

  # Private helper functions

  defp count_elements(svg_content, element) do
    case Regex.scan(~r/<#{element}[\s>]/i, svg_content) do
      nil -> 0
      matches -> length(matches)
    end
  end

  defp extract_svg_attributes(svg_content) do
    # This is a simple regex approach - a proper XML parser would be better
    case Regex.run(~r/<svg([^>]*)>/i, svg_content) do
      [_, attrs_str] ->
        # Extract attribute pairs
        Regex.scan(~r/([a-zA-Z0-9_\-:]+)=["']([^"']*)["']/i, attrs_str)
        |> Enum.map(fn [_, name, value] -> {name, value} end)
        |> Map.new()

      _ -> %{}
    end
  end

  defp identify_svg_issues(_svg_content, element_counts, svg_attrs) do
    issues = []

    # Check for missing viewBox
    issues = if !Map.has_key?(svg_attrs, "viewBox") do
      issues ++ ["Missing viewBox attribute"]
    else
      issues
    end

    # Check for fixed width/height
    issues = if Map.has_key?(svg_attrs, "width") && Map.has_key?(svg_attrs, "height") do
      width = svg_attrs["width"]
      height = svg_attrs["height"]

      if String.contains?(width || "", "px") || String.contains?(height || "", "px") do
        issues ++ ["Fixed pixel dimensions (use relative units or viewBox only)"]
      else
        issues
      end
    else
      issues
    end

    # Check for outdated elements
    outdated_elements = []
    outdated_elements = if element_counts["g"] > 0, do: outdated_elements ++ ["g"], else: outdated_elements
    outdated_elements = if element_counts["polygon"] > 0, do: outdated_elements ++ ["polygon"], else: outdated_elements
    outdated_elements = if element_counts["rect"] > 0, do: outdated_elements ++ ["rect"], else: outdated_elements

    issues = if length(outdated_elements) > 0 do
      issues ++ ["Contains outdated elements that could be converted to paths: #{Enum.join(outdated_elements, ", ")}"]
    else
      issues
    end

    # Check for external style tag vs. inline styles
    issues = if element_counts["style"] > 0 do
      issues ++ ["Contains style tags (consider inline styles)"]
    else
      issues
    end

    issues
  end

  defp format_file_size(bytes) when is_integer(bytes) do
    cond do
      bytes < 1024 -> "#{bytes} B"
      bytes < 1024 * 1024 -> "#{Float.round(bytes / 1024, 2)} KB"
      true -> "#{Float.round(bytes / (1024 * 1024), 2)} MB"
    end
  end

  # Process style elements
  defp process_style_elements(svg_content) do
    # Check if there are style elements
    style_pattern = ~r/<style[^>]*>(.*?)<\/style>/s
    styles = Regex.scan(style_pattern, svg_content)

    if Enum.empty?(styles) do
      {svg_content, []}
    else
      # In a real implementation, we would parse the CSS and apply it inline
      # For now, just note the style elements
      {svg_content, ["Detected #{length(styles)} style elements, consider converting to inline styles"]}
    end
  end

  # Process groups
  defp process_groups(svg_content) do
    # Check if there are group elements
    group_count = Regex.scan(~r/<g[^>]*>/i, svg_content) |> length()

    if group_count == 0 do
      {svg_content, []}
    else
      # In a real implementation, we would flatten groups
      # For now, just note the group elements
      {svg_content, ["Detected #{group_count} group elements, consider flattening where possible"]}
    end
  end

  # Convert shapes to paths
  defp convert_shapes_to_paths(svg_content) do
    changes = []

    # Convert rect elements
    {svg_content, rect_count} = convert_rect_elements(svg_content)
    changes = if rect_count > 0, do: changes ++ ["Converted #{rect_count} rect elements to paths"], else: changes

    # Convert circle elements
    {svg_content, circle_count} = convert_circle_elements(svg_content)
    changes = if circle_count > 0, do: changes ++ ["Converted #{circle_count} circle elements to paths"], else: changes

    # Convert polygon elements
    {svg_content, polygon_count} = convert_polygon_elements(svg_content)
    changes = if polygon_count > 0, do: changes ++ ["Converted #{polygon_count} polygon elements to paths"], else: changes

    {svg_content, changes}
  end

  # Convert rect elements to path
  defp convert_rect_elements(svg_content) do
    rect_pattern = ~r/<rect([^>]*)\/?>(?:<\/rect>)?/i
    rects = Regex.scan(rect_pattern, svg_content, capture: :all)

    if Enum.empty?(rects) do
      {svg_content, 0}
    else
      new_svg = Enum.reduce(rects, svg_content, fn [full_match, attrs], content ->
        # Parse attributes
        attrs_map = parse_attrs(attrs)

        # Convert to path
        path_data = IconsLvDraft.SVGPathConverter.rect_to_path(attrs_map)

        # Create new path element, preserving other attributes
        preserved_attrs = preserve_attrs(attrs, ~w(x y width height rx ry))
        new_element = "<path d=\"#{path_data}\"#{preserved_attrs}/>"

        # Replace in content
        String.replace(content, full_match, new_element, global: false)
      end)

      {new_svg, length(rects)}
    end
  end

  # Convert circle elements to path
  defp convert_circle_elements(svg_content) do
    circle_pattern = ~r/<circle([^>]*)\/?>(?:<\/circle>)?/i
    circles = Regex.scan(circle_pattern, svg_content, capture: :all)

    if Enum.empty?(circles) do
      {svg_content, 0}
    else
      new_svg = Enum.reduce(circles, svg_content, fn [full_match, attrs], content ->
        # Parse attributes
        attrs_map = parse_attrs(attrs)

        # Convert to path
        path_data = IconsLvDraft.SVGPathConverter.circle_to_path(attrs_map)

        # Create new path element, preserving other attributes
        preserved_attrs = preserve_attrs(attrs, ~w(cx cy r))
        new_element = "<path d=\"#{path_data}\"#{preserved_attrs}/>"

        # Replace in content
        String.replace(content, full_match, new_element, global: false)
      end)

      {new_svg, length(circles)}
    end
  end

  # Convert polygon elements to path
  defp convert_polygon_elements(svg_content) do
    polygon_pattern = ~r/<polygon([^>]*)\/?>(?:<\/polygon>)?/i
    polygons = Regex.scan(polygon_pattern, svg_content, capture: :all)

    if Enum.empty?(polygons) do
      {svg_content, 0}
    else
      new_svg = Enum.reduce(polygons, svg_content, fn [full_match, attrs], content ->
        # Parse attributes
        attrs_map = parse_attrs(attrs)

        # Convert to path
        path_data = IconsLvDraft.SVGPathConverter.polygon_to_path(attrs_map)

        # Create new path element, preserving other attributes
        preserved_attrs = preserve_attrs(attrs, ~w(points))
        new_element = "<path d=\"#{path_data}\"#{preserved_attrs}/>"

        # Replace in content
        String.replace(content, full_match, new_element, global: false)
      end)

      {new_svg, length(polygons)}
    end
  end

  # Parse attributes from string
  defp parse_attrs(attrs_str) do
    attr_pattern = ~r/\s*([a-zA-Z0-9_\-:]+)=["']([^"']*)["']/

    Regex.scan(attr_pattern, attrs_str)
    |> Enum.map(fn [_, name, value] -> {name, value} end)
    |> Enum.into(%{})
  end

  # Preserve attributes except for specific ones
  defp preserve_attrs(attrs_str, exclude_attrs) do
    attr_pattern = ~r/\s*([a-zA-Z0-9_\-:]+)=["']([^"']*)["']/

    Regex.scan(attr_pattern, attrs_str)
    |> Enum.reject(fn [_, name, _] -> name in exclude_attrs end)
    |> Enum.map(fn [_, name, value] -> " #{name}=\"#{value}\"" end)
    |> Enum.join("")
  end

  # Clean up unnecessary attributes
  defp clean_attributes(svg_content) do
    # Find elements with IDs
    id_count = Regex.scan(~r/\sid=["'][^"']*["']/i, svg_content) |> length()

    # Find empty attributes
    empty_attr_count = Regex.scan(~r/\s[a-zA-Z0-9_\-:]+=[""]["']/i, svg_content) |> length()

    changes = []
    changes = if id_count > 0, do: changes ++ ["Found #{id_count} id attributes, consider removing if not referenced"], else: changes
    changes = if empty_attr_count > 0, do: changes ++ ["Found #{empty_attr_count} empty attributes, should be removed"], else: changes

    # In a real implementation, we would clean up these attributes
    # For now, just return the content unchanged
    {svg_content, changes}
  end

  # Ensure viewBox is present
  defp ensure_viewbox(svg_content) do
    # Check if viewBox is already present
    has_viewbox = Regex.match?(~r/viewBox=["'][^"']*["']/i, svg_content)

    if has_viewbox do
      {svg_content, []}
    else
      # Try to extract width and height from SVG tag
      width_match = Regex.run(~r/\swidth=["']([^"']*)["']/i, svg_content)
      height_match = Regex.run(~r/\sheight=["']([^"']*)["']/i, svg_content)

      if width_match && height_match do
        width_str = Enum.at(width_match, 1)
        height_str = Enum.at(height_match, 1)

        width = parse_dimension(width_str)
        height = parse_dimension(height_str)

        if width && height do
          # Add viewBox attribute to the SVG tag
          viewbox = "0 0 #{width} #{height}"
          new_svg = Regex.replace(~r/<svg/, svg_content, "<svg viewBox=\"#{viewbox}\"", global: false)

          {new_svg, ["Added viewBox=\"#{viewbox}\" based on width/height"]}
        else
          {svg_content, ["Missing viewBox and could not determine from dimensions"]}
        end
      else
        {svg_content, ["Missing viewBox attribute and no width/height to generate one"]}
      end
    end
  end

  defp parse_dimension(dim_str) when is_binary(dim_str) do
    # Extract numeric part from dimension
    case Regex.run(~r/^(\d+(\.\d+)?)/, dim_str) do
      [_, num, _] ->
        case Float.parse(num) do
          {float_val, _} -> float_val
          :error -> nil
        end
      [_, num] ->
        case Integer.parse(num) do
          {int_val, _} -> int_val
          :error -> nil
        end
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp parse_dimension(_), do: nil
end
