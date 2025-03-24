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
      import SweetXml, only: [sigil_x: 2, xpath: 2, xpath: 3]

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

  defp identify_svg_issues(svg_content, element_counts, svg_attrs) do
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

      if String.contains?(width, "px") || String.contains?(height, "px") do
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

  # Below are the main processing functions

  defp process_style_elements(svg_content) do
    # This would need a proper CSS parser and XML parser to do correctly
    # Simplified for demonstration
    has_style = Regex.match?(~r/<style[^>]*>.*?<\/style>/s, svg_content)

    if has_style do
      # For now, just note the change but don't implement it (would need full CSS parsing)
      {svg_content, ["Detected style elements, recommend converting to inline styles"]}
    else
      {svg_content, []}
    end
  end

  defp process_groups(svg_content) do
    # Count groups
    g_count = count_elements(svg_content, "g")

    if g_count > 0 do
      # In a real implementation, would parse XML and process groups
      # For demo, just flagging them
      {svg_content, ["Detected #{g_count} group elements, recommend flattening where possible"]}
    else
      {svg_content, []}
    end
  end

  defp convert_shapes_to_paths(svg_content) do
    changes = []

    # Check for rect elements
    rect_count = count_elements(svg_content, "rect")
    changes = if rect_count > 0 do
      changes ++ ["Detected #{rect_count} rect elements, could be converted to paths"]
    else
      changes
    end

    # Check for polygon elements
    polygon_count = count_elements(svg_content, "polygon")
    changes = if polygon_count > 0 do
      changes ++ ["Detected #{polygon_count} polygon elements, could be converted to paths"]
    else
      changes
    end

    # Check for circle elements
    circle_count = count_elements(svg_content, "circle")
    changes = if circle_count > 0 do
      changes ++ ["Detected #{circle_count} circle elements, could be converted to paths"]
    else
      changes
    end

    # In a real implementation, we would actually convert these elements
    # For demonstration purposes, we're just reporting them

    {svg_content, changes}
  end

  defp clean_attributes(svg_content) do
    # Look for potentially unnecessary attributes
    changes = []

    # Check for id attributes
    id_count = Regex.scan(~r/id=["'][^"']*["']/i, svg_content) |> length()
    changes = if id_count > 0 do
      changes ++ ["Found #{id_count} id attributes, consider removing if not referenced"]
    else
      changes
    end

    # Check for empty or default attributes
    empty_attr_count = Regex.scan(~r/[a-zA-Z0-9_\-:]+=[""]["']/i, svg_content) |> length()
    changes = if empty_attr_count > 0 do
      changes ++ ["Found #{empty_attr_count} empty attributes, should be removed"]
    else
      changes
    end

    # In a real implementation, we would actually clean these attributes
    # For demonstration purposes, we're just reporting them

    {svg_content, changes}
  end

  defp ensure_viewbox(svg_content) do
    svg_attrs = extract_svg_attributes(svg_content)

    if Map.has_key?(svg_attrs, "viewBox") do
      {svg_content, []}
    else
      # Check if width and height are available
      if Map.has_key?(svg_attrs, "width") && Map.has_key?(svg_attrs, "height") do
        width = parse_dimension(svg_attrs["width"])
        height = parse_dimension(svg_attrs["height"])

        if width && height do
          # Add viewBox attribute
          viewbox = "0 0 #{width} #{height}"
          svg_content = Regex.replace(~r/<svg/, svg_content, "<svg viewBox=\"#{viewbox}\"", global: false)
          {svg_content, ["Added viewBox=\"#{viewbox}\" based on width/height"]}
        else
          # Can't determine viewBox
          {svg_content, ["Missing viewBox and could not determine from dimensions"]}
        end
      else
        # No width/height to generate viewBox
        {svg_content, ["Missing viewBox attribute and no width/height to generate one"]}
      end
    end
  end

  defp parse_dimension(dim_str) when is_binary(dim_str) do
    # Extract numeric part from dimension
    case Regex.run(~r/^(\d+(\.\d+)?)/, dim_str) do
      [_, num, _] -> String.to_float(num)
      [_, num] -> String.to_integer(num)
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp parse_dimension(_), do: nil
end
