defmodule IconsLvDraft.SVGPathConverter do
  @moduledoc """
  Provides functions to convert various SVG elements to path elements.

  This module contains implementations for converting:
  - rect elements to path
  - circle elements to path
  - ellipse elements to path
  - line elements to path
  - polygon elements to path
  - polyline elements to path
  """

  @doc """
  Convert a rect element to an equivalent path element.

  ## Parameters
  - `attrs` - Map of attribute names to values for the rect

  ## Returns
  A string containing the path data ('d' attribute)
  """
  def rect_to_path(attrs) do
    x = parse_attr(attrs["x"], "0")
    y = parse_attr(attrs["y"], "0")
    width = parse_attr(attrs["width"], "0")
    height = parse_attr(attrs["height"], "0")
    rx = parse_attr(attrs["rx"], "0")
    ry = parse_attr(attrs["ry"], "0")

    # If only one radius is specified, both get the same value
    rx = if rx != 0 && ry == 0, do: rx, else: rx
    ry = if ry != 0 && rx == 0, do: rx, else: ry

    # If rx or ry is more than half the width or height, it's capped
    rx = min(rx, width / 2)
    ry = min(ry, height / 2)

    if rx == 0 && ry == 0 do
      # No rounded corners
      "M#{x},#{y} h#{width} v#{height} h#{-width} Z"
    else
      # Rounded corners
      "M#{x + rx},#{y} " <>
      "h#{width - 2 * rx} " <>
      "a#{rx},#{ry} 0 0 1 #{rx},#{ry} " <>
      "v#{height - 2 * ry} " <>
      "a#{rx},#{ry} 0 0 1 #{-rx},#{ry} " <>
      "h#{-(width - 2 * rx)} " <>
      "a#{rx},#{ry} 0 0 1 #{-rx},#{-ry} " <>
      "v#{-(height - 2 * ry)} " <>
      "a#{rx},#{ry} 0 0 1 #{rx},#{-ry} " <>
      "Z"
    end
  end

  @doc """
  Convert a circle element to an equivalent path element.

  ## Parameters
  - `attrs` - Map of attribute names to values for the circle

  ## Returns
  A string containing the path data ('d' attribute)
  """
  def circle_to_path(attrs) do
    cx = parse_attr(attrs["cx"], "0")
    cy = parse_attr(attrs["cy"], "0")
    r = parse_attr(attrs["r"], "0")

    "M#{cx - r},#{cy} " <>
    "a#{r},#{r} 0 1,0 #{2 * r},0 " <>
    "a#{r},#{r} 0 1,0 #{-2 * r},0 " <>
    "Z"
  end

  @doc """
  Convert an ellipse element to an equivalent path element.

  ## Parameters
  - `attrs` - Map of attribute names to values for the ellipse

  ## Returns
  A string containing the path data ('d' attribute)
  """
  def ellipse_to_path(attrs) do
    cx = parse_attr(attrs["cx"], "0")
    cy = parse_attr(attrs["cy"], "0")
    rx = parse_attr(attrs["rx"], "0")
    ry = parse_attr(attrs["ry"], "0")

    "M#{cx - rx},#{cy} " <>
    "a#{rx},#{ry} 0 1,0 #{2 * rx},0 " <>
    "a#{rx},#{ry} 0 1,0 #{-2 * rx},0 " <>
    "Z"
  end

  @doc """
  Convert a line element to an equivalent path element.

  ## Parameters
  - `attrs` - Map of attribute names to values for the line

  ## Returns
  A string containing the path data ('d' attribute)
  """
  def line_to_path(attrs) do
    x1 = parse_attr(attrs["x1"], "0")
    y1 = parse_attr(attrs["y1"], "0")
    x2 = parse_attr(attrs["x2"], "0")
    y2 = parse_attr(attrs["y2"], "0")

    "M#{x1},#{y1} L#{x2},#{y2}"
  end

  @doc """
  Convert a polygon element to an equivalent path element.

  ## Parameters
  - `attrs` - Map of attribute names to values for the polygon

  ## Returns
  A string containing the path data ('d' attribute)
  """
  def polygon_to_path(attrs) do
    points = attrs["points"] || ""

    if points == "" do
      ""
    else
      points = String.trim(points)

      # Split into pairs and process
      pairs = String.split(points, ~r/\s+|,/)
      |> Enum.chunk_every(2)
      |> Enum.filter(fn chunk -> length(chunk) == 2 end)

      case pairs do
        [] -> ""
        [first | rest] ->
          # Start with a move to the first point
          path = "M#{Enum.at(first, 0)},#{Enum.at(first, 1)}"

          # Add line segments to each subsequent point
          path = Enum.reduce(rest, path, fn [x, y], acc ->
            acc <> " L#{x},#{y}"
          end)

          # Close the path
          path <> " Z"
      end
    end
  end

  @doc """
  Convert a polyline element to an equivalent path element.
  Similar to polygon but doesn't close the path.

  ## Parameters
  - `attrs` - Map of attribute names to values for the polyline

  ## Returns
  A string containing the path data ('d' attribute)
  """
  def polyline_to_path(attrs) do
    points = attrs["points"] || ""

    if points == "" do
      ""
    else
      points = String.trim(points)

      # Split into pairs and process
      pairs = String.split(points, ~r/\s+|,/)
      |> Enum.chunk_every(2)
      |> Enum.filter(fn chunk -> length(chunk) == 2 end)

      case pairs do
        [] -> ""
        [first | rest] ->
          # Start with a move to the first point
          path = "M#{Enum.at(first, 0)},#{Enum.at(first, 1)}"

          # Add line segments to each subsequent point
          Enum.reduce(rest, path, fn [x, y], acc ->
            acc <> " L#{x},#{y}"
          end)
      end
    end
  end

  @doc """
  Generate a new path element string from the original element and new path data.

  ## Parameters
  - `_original_element` - The original element string (unused, prefixed with underscore)
  - `path_data` - The path data to use
  - `attrs` - Map of attribute names to values to preserve

  ## Returns
  A string containing the new path element
  """
  def generate_path_element(_original_element, path_data, attrs) do
    # Preserve all attributes except the element-specific ones
    excluded_attrs = ~w(x y cx cy r rx ry x1 y1 x2 y2 width height points)

    preserved_attrs = attrs
    |> Enum.filter(fn {k, _} -> k not in excluded_attrs end)
    |> Enum.map(fn {k, v} -> "#{k}=\"#{v}\"" end)
    |> Enum.join(" ")

    # Construct the path element
    "<path d=\"#{path_data}\" #{preserved_attrs}/>"
  end

  # Private helper functions

  defp parse_attr(nil, default), do: parse_attr(default, default)
  defp parse_attr(value, _default) when is_number(value), do: value
  defp parse_attr(value, default) when is_binary(value) do
    case Float.parse(value) do
      {num, _} -> num
      :error -> parse_attr(default, default)
    end
  end
  defp parse_attr(_, default), do: parse_attr(default, default)
end
