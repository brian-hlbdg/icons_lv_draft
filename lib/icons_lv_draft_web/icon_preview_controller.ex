defmodule IconsLvDraftWeb.IconPreviewController do
  use IconsLvDraftWeb, :controller

  @doc """
  Renders a single icon in an isolated environment
  """
  def show(conn, params) do
    # Extract parameters
    icon_path = params["path"]
    base_color = params["base"] || "currentColor"
    active_color = params["active"]
    warning_color = params["warning"]

    if icon_path do
      # Split the icon path into category and name
      [category, name] = String.split(icon_path, "/", parts: 2)
      file_path = Application.app_dir(:icons_lv_draft, "priv/static/icons/#{category}/#{name}.svg")

      case File.read(file_path) do
        {:ok, svg_content} ->
          # Process SVG to add colors
          svg_content = process_svg(svg_content, base_color, active_color, warning_color)

          # Send the HTML with just this single icon
          html = """
          <!DOCTYPE html>
          <html>
            <head>
              <meta charset="UTF-8">
              <style>
                html, body {
                  margin: 0;
                  padding: 0;
                  width: 100%;
                  height: 100%;
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  background: transparent;
                }
                svg {
                  width: 80%;
                  height: 80%;
                  max-width: 64px;
                  max-height: 64px;
                }
              </style>
            </head>
            <body>
              #{svg_content}
            </body>
          </html>
          """

          conn
          |> put_resp_content_type("text/html")
          |> send_resp(200, html)

        {:error, reason} ->
          # Send error message
          conn
          |> put_resp_content_type("text/html")
          |> send_resp(404, "Icon not found: #{inspect(reason)}")
      end
    else
      # No icon path provided
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(400, "No icon path provided")
    end
  end

  # Process SVG to apply colors
  defp process_svg(svg_content, base_color, active_color, warning_color) do
    # Replace currentColor with the base color if provided and different
    svg_content = if base_color && base_color != "currentColor" do
      String.replace(svg_content, "currentColor", base_color)
    else
      svg_content
    end

    # Add additional color variables if needed
    if active_color || warning_color do
      # Extract closing svg tag to add styles before it
      case Regex.run(~r/(.*?)(<\/svg>)$/, svg_content, capture: :all_but_first) do
        [content, closing] ->
          # Build style tag with variables
          style_tag = "<style>"
          style_tag = if active_color, do: style_tag <> " :root { --active-color: #{active_color}; }", else: style_tag
          style_tag = if warning_color, do: style_tag <> " :root { --warning-color: #{warning_color}; }", else: style_tag
          style_tag = style_tag <> "</style>"

          # Insert style before closing svg tag
          content <> style_tag <> closing

        _ ->
          # If regex doesn't match, return the original content
          svg_content
      end
    else
      svg_content
    end
  end
end
