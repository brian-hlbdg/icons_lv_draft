defmodule IconsLvDraftWeb.IconGalleryLive do
  use IconsLvDraftWeb, :live_view

  alias IconsLvDraft.Categories

  def mount(_params, _session, socket) do
    categories = Categories.all()

    socket = assign(socket,
      categories: categories,
      current_category: List.first(categories),
      icons: [],
      base_color: "currentColor",
      active_color: nil,
      warning_color: nil,
      search_term: nil,
      copied_icon: nil,
      current_icon: nil,
      processed_svg: nil,
      show_color_options: false,  # Set to false by default
      color_error: nil,           # Add error state for color changes
      svg_content: nil            # Store the raw SVG content for analysis
    )

    {:ok, socket}
  end

  def handle_event("select_icon", %{"icon" => icon_path}, socket) do
    # Read the SVG content and detect colors
    svg_content = read_svg_content(icon_path)

    # Check if coloration is possible and extract dominant color
    {can_customize, dominant_color} = check_svg_customization(svg_content)

    # Set initial color based on detection
    base_color = if dominant_color && dominant_color != "", do: dominant_color, else: "currentColor"

    # Process the SVG with the detected color
    processed_svg = process_icon_svg(icon_path, "selected-icon-preview",
      base_color: base_color)

    # Reset color error when selecting a new icon
    {:noreply, assign(socket,
      current_icon: icon_path,
      processed_svg: processed_svg,
      show_color_options: false,        # Always hide color options when selecting a new icon
      color_error: nil,                # Reset any color error messages
      base_color: base_color,          # Set the base color to detected color
      svg_content: svg_content,        # Store SVG content for later analysis
      can_customize: can_customize     # Store whether SVG can be customized
    )}
  end

  def handle_params(%{"category" => category_id}, _uri, socket) do
    category = Categories.get_category(category_id)
    icons = Categories.list_icons(category_id)

    socket = assign(socket,
      current_category: category,
      icons: icons,
      page_title: "#{category.name} Icons"
    )

    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    %{id: category_id} = List.first(socket.assigns.categories)
    icons = Categories.list_icons(category_id)

    socket = assign(socket,
      icons: icons,
      page_title: "Icon Gallery"
    )

    {:noreply, socket}
  end

  def handle_event("search", %{"search" => %{"term" => term}}, socket) do
    %{current_category: %{id: category_id}} = socket.assigns

    icons =
      if term == "" do
        Categories.list_icons(category_id)
      else
        Categories.list_icons(category_id)
        |> Enum.filter(&String.contains?(String.downcase(&1.name), String.downcase(term)))
      end

    {:noreply, assign(socket, icons: icons, search_term: term)}
  end

  def handle_event("update-color", %{"color" => color_type, "value" => value}, socket) do
    value = if value == "", do: nil, else: value

    # Update the color in the socket assigns
    socket = case color_type do
      "base" -> assign(socket, base_color: value)
      "active" -> assign(socket, active_color: value)
      "warning" -> assign(socket, warning_color: value)
    end

    # If there's a currently selected icon, update the processed SVG
    socket = if socket.assigns.current_icon do
      # Check if color customization is possible
      can_customize = socket.assigns.can_customize

      if !can_customize && color_type == "base" && value != "currentColor" do
        # If SVG doesn't support colors, show an error
        assign(socket, color_error: "This SVG doesn't support color customization")
      else
        # Try to process the SVG with the new color
        processed_svg = process_icon_svg(
          socket.assigns.current_icon,
          "selected-icon-preview",
          base_color: socket.assigns.base_color,
          active_color: socket.assigns.active_color,
          warning_color: socket.assigns.warning_color
        )

        if processed_svg do
          # Color change successful
          assign(socket, processed_svg: processed_svg, color_error: nil)
        else
          # Color change failed - keep the old SVG and show an error
          assign(socket, color_error: "Failed to apply color changes to this SVG")
        end
      end
    else
      socket
    end

    {:noreply, socket}
  end

  def handle_event("copy-code", %{"format" => format, "icon" => icon_path}, socket) do
    %{base_color: base_color, active_color: active_color, warning_color: warning_color} = socket.assigns

    # Check if we're copying from a different icon than the currently previewed one
    # If so, update the preview to show this icon
    socket = if icon_path != socket.assigns.current_icon do
      # Read the SVG content and detect colors
      svg_content = read_svg_content(icon_path)

      # Check if coloration is possible and extract dominant color
      {can_customize, dominant_color} = check_svg_customization(svg_content)

      # Use the detected dominant color as the initial color
      new_base_color = if dominant_color && dominant_color != "", do: dominant_color, else: "currentColor"

      processed_svg = process_icon_svg(icon_path, "selected-icon-preview",
        base_color: new_base_color)

      assign(socket,
        current_icon: icon_path,
        processed_svg: processed_svg,
        color_error: nil,
        base_color: new_base_color,
        svg_content: svg_content,
        can_customize: can_customize
      )
    else
      socket
    end

    code =
      case format do
        "html" ->
          IconsLvDraft.generate_html_code(icon_path,
            base_color: base_color,
            active_color: active_color,
            warning_color: warning_color
          )

        "liveview" ->
          IconsLvDraft.generate_liveview_code(icon_path,
            base_color: base_color,
            active_color: active_color,
            warning_color: warning_color
          )
      end

    # In a real app, you'd use JS interop to copy to clipboard
    # For now, we'll just show what's been "copied"
    {:noreply, assign(socket, copied_icon: %{path: icon_path, code: code, format: format})}
  end

  def handle_event("toggle-customization", _params, socket) do
    # Toggle the show_color_options flag
    {:noreply, assign(socket, show_color_options: !socket.assigns.show_color_options)}
  end

  def handle_event("close_detail", _params, socket) do
    {:noreply, assign(socket,
      current_icon: nil,
      processed_svg: nil,
      show_color_options: false,
      color_error: nil,
      svg_content: nil,
      can_customize: nil
    )}
  end

  # Read SVG content from a file
  defp read_svg_content(icon_path) do
    try do
      # Split the icon path into category and name
      [category, name] = String.split(icon_path, "/", parts: 2)
      file_path = Application.app_dir(:icons_lv_draft, "priv/static/icons/#{category}/#{name}.svg")

      # Read the SVG file
      {:ok, svg_content} = File.read(file_path)
      svg_content
    rescue
      _ -> ""  # Return empty string if there's an error
    end
  end

  # Check if SVG supports color customization and extract color
  defp check_svg_customization(svg_content) do
    # Check for fill attribute
    fill_color = extract_fill_color(svg_content)
    has_fill = String.match?(svg_content, ~r/fill=["']([^"']+)["']/)
    has_stroke = String.match?(svg_content, ~r/stroke=["']([^"']+)["']/)
    has_current_color = String.contains?(svg_content, "currentColor")

    # Determine if SVG can be customized
    can_customize = has_fill || has_stroke || has_current_color

    # Return both customization flag and dominant color
    {can_customize, fill_color}
  end

  # Extract fill color from SVG content
  defp extract_fill_color(svg_content) do
    # Match fill attribute with color value
    case Regex.run(~r/fill=["']([^"']+)["']/, svg_content, capture: :all_but_first) do
      [color] when color != "none" -> color
      _ -> nil
    end
  end

  # Process an icon SVG file with the current color settings
  # Process an icon SVG file with the current color settings
  # Process an icon SVG file with the current color settings
defp process_icon_svg(icon_path, element_id, opts \\ []) do
  # Get the colors from options or use the defaults
  base_color = Keyword.get(opts, :base_color, "currentColor")
  active_color = Keyword.get(opts, :active_color)
  warning_color = Keyword.get(opts, :warning_color)

  try do
    # Generate basic SVG by reading from file
    [category, name] = String.split(icon_path, "/", parts: 2)
    file_path = Application.app_dir(:icons_lv_draft, "priv/static/icons/#{category}/#{name}.svg")

    # Read the SVG directly from file
    {:ok, svg_content} = File.read(file_path)

    # Apply base color if needed
    svg_content = if base_color != "currentColor" do
      svg_content
      |> String.replace("fill=\"currentColor\"", "fill=\"#{base_color}\"")
      |> String.replace("stroke=\"currentColor\"", "stroke=\"#{base_color}\"")
    else
      svg_content
    end

    # First, remove any existing IDs to avoid conflicts
    svg_without_ids = Regex.replace(~r/(<[^>]*)id="[^"]*"([^>]*)/, svg_content, "\\1\\2")

    # Generate a unique ID that includes timestamp to ensure uniqueness
    unique_id = "#{element_id}-#{:os.system_time(:millisecond)}-#{:erlang.unique_integer([:positive])}"

    # Add our unique ID to the SVG
    svg_with_id = String.replace(svg_without_ids, "<svg", "<svg id=\"#{unique_id}\"", global: false)

    # Add color variables if needed
    svg_with_colors = add_color_variables(svg_with_id, active_color, warning_color)

    # Add class for styling
    String.replace(svg_with_colors, "<svg", "<svg class=\"w-full h-full\"", global: false)
  rescue
    _ -> nil  # Return nil on error
  end
end

  # Helper to add color variables
  defp add_color_variables(svg, nil, nil), do: svg
  defp add_color_variables(svg, active_color, nil) do
    String.replace(svg, "</svg>", "<style>:root{--active-color:#{active_color};}</style></svg>")
  end
  defp add_color_variables(svg, nil, warning_color) do
    String.replace(svg, "</svg>", "<style>:root{--warning-color:#{warning_color};}</style></svg>")
  end
  defp add_color_variables(svg, active_color, warning_color) do
    String.replace(svg, "</svg>", "<style>:root{--active-color:#{active_color};--warning-color:#{warning_color};}</style></svg>")
  end

  # In Phoenix 1.7, the template is in a separate function
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-3xl font-bold mb-6">IconsLv Gallery</h1>

      <div class="mb-8 flex flex-wrap gap-4">
        <%= for category <- @categories do %>
          <.link
            navigate={~p"/category/#{category.id}"}
            class={"px-4 py-2 rounded #{if @current_category.id == category.id, do: "bg-blue-500 text-white", else: "bg-gray-200"}"}
          >
            <%= category.name %>
          </.link>
        <% end %>
      </div>

      <div class="mb-8">
        <h2 class="text-2xl font-semibold mb-4"><%= @current_category.name %> Icons</h2>
        <p class="text-gray-600 mb-4"><%= @current_category.description %></p>

        <form phx-change="search" class="mb-6">
          <div class="flex gap-4">
            <div class="w-1/2">
              <label for="search_term" class="block text-sm font-medium text-gray-700 mb-1">Search Icons</label>
              <input
                type="text"
                name="search[term]"
                value={@search_term}
                placeholder="Search icons..."
                class="w-full px-3 py-2 border border-gray-300 rounded-md"
              />
            </div>
          </div>
        </form>

        <%= if @current_icon && @processed_svg do %>
          <div class="mb-8 p-6 bg-white border rounded-lg shadow-sm">
            <div class="flex justify-between items-center mb-4">
              <h3 class="text-lg font-medium">Icon Preview</h3>
              <div class="flex gap-2">
                <button
                  phx-click="toggle-customization"
                  class="px-3 py-1 text-sm bg-blue-100 text-blue-700 rounded hover:bg-blue-200 flex items-center"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                  </svg>
                  <%= if @show_color_options, do: "Hide Customization", else: "Customize Colors" %>
                </button>
                <button
                  phx-click="close_detail"
                  class="px-3 py-1 text-sm bg-gray-200 text-gray-700 rounded hover:bg-gray-300 flex items-center"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                  Close
                </button>
              </div>
            </div>

            <div class="flex justify-center items-center h-32 p-4 border rounded-lg bg-gray-50 mb-4">
              <%= Phoenix.HTML.raw(@processed_svg) %>
            </div>

            <%= if @color_error do %>
              <div class="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg text-red-600 text-sm">
                <div class="flex items-center">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                  </svg>
                  <%= @color_error %>
                </div>
              </div>
            <% end %>

            <!-- Add SVG color information message -->
            <%= if @svg_content do %>
              <div class="mb-4 p-3 bg-blue-50 border border-blue-200 rounded-lg text-blue-700 text-sm">
                <div class="flex items-center">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  <%= if @can_customize do %>
                    This SVG supports color customization.
                  <% else %>
                    This SVG doesn't support color customization.
                  <% end %>
                </div>
              </div>
            <% end %>

            <%= if @show_color_options do %>
              <div class="mb-4 p-4 bg-gray-50 border rounded-lg">
                <h4 class="text-sm font-medium text-gray-700 mb-3">Color Customization</h4>
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <!-- Base color input -->
                  <div>
                    <label for="base_color" class="block text-sm font-medium text-gray-700 mb-1">Base Color</label>
                    <div class="flex">
                      <input type="text" name="base_color" value={@base_color} placeholder="e.g., #000000, currentColor"
                        phx-change="update-color" phx-value-color="base"
                        class="w-full px-3 py-2 border border-gray-300 rounded-l-md"
                        disabled={!@can_customize} />
                      <div class="w-10 border-t border-r border-b border-gray-300 rounded-r-md flex items-center justify-center"
                          style={"background-color: #{if @base_color == "currentColor", do: "#000000", else: @base_color};"}>
                      </div>
                    </div>
                    <div class="text-xs text-gray-500 mt-1">Current value: <%= @base_color %></div>
                  </div>

                  <!-- Active color input -->
                  <div>
                    <label for="active_color" class="block text-sm font-medium text-gray-700 mb-1">Active Color (optional)</label>
                    <div class="flex">
                      <input type="text" name="active_color" value={@active_color} placeholder="e.g., #0066cc"
                        phx-change="update-color" phx-value-color="active"
                        class="w-full px-3 py-2 border border-gray-300 rounded-l-md"
                        disabled={!@can_customize} />
                      <%= if @active_color do %>
                        <div class="w-10 border-t border-r border-b border-gray-300 rounded-r-md flex items-center justify-center"
                            style={"background-color: #{@active_color};"}>
                        </div>
                      <% else %>
                        <div class="w-10 border-t border-r border-b border-gray-300 rounded-r-md flex items-center justify-center bg-gray-200">
                        </div>
                      <% end %>
                    </div>
                    <div class="text-xs text-gray-500 mt-1">Current value: <%= @active_color || "none" %></div>
                  </div>

                  <!-- Warning color input -->
                  <div>
                    <label for="warning_color" class="block text-sm font-medium text-gray-700 mb-1">Warning Color (optional)</label>
                    <div class="flex">
                      <input type="text" name="warning_color" value={@warning_color} placeholder="e.g., #ff0000"
                        phx-change="update-color" phx-value-color="warning"
                        class="w-full px-3 py-2 border border-gray-300 rounded-l-md"
                        disabled={!@can_customize} />
                      <%= if @warning_color do %>
                        <div class="w-10 border-t border-r border-b border-gray-300 rounded-r-md flex items-center justify-center"
                            style={"background-color: #{@warning_color};"}>
                        </div>
                      <% else %>
                        <div class="w-10 border-t border-r border-b border-gray-300 rounded-r-md flex items-center justify-center bg-gray-200">
                        </div>
                      <% end %>
                    </div>
                    <div class="text-xs text-gray-500 mt-1">Current value: <%= @warning_color || "none" %></div>
                  </div>
                </div>
              </div>
            <% end %>

            <div class="flex justify-center gap-4 mt-4">
              <button
                phx-click="copy-code"
                phx-value-format="html"
                phx-value-icon={@current_icon}
                class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 flex items-center"
              >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                </svg>
                Copy HTML
              </button>
              <button
                phx-click="copy-code"
                phx-value-format="liveview"
                phx-value-icon={@current_icon}
                class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 flex items-center"
              >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                </svg>
                Copy LiveView
              </button>
            </div>

            <!-- Include a description of the SVG colorability -->
            <div class="mt-4 text-sm text-gray-600">
              <%= if @can_customize do %>
                <p>This SVG supports color customization via the color pickers above.</p>
              <% else %>
                <p><strong>Note:</strong> This SVG doesn't support color customization. The code will use the original colors of the SVG.</p>
              <% end %>
            </div>
          </div>

          <%= if @copied_icon do %>
            <div class="mb-8 p-6 border rounded-lg bg-gray-50">
              <h3 class="text-xl font-semibold mb-4">Copied <%= String.upcase(@copied_icon.format) %> Code</h3>
              <div class="bg-white p-4 border rounded overflow-x-auto">
                <pre class="text-sm"><code><%= @copied_icon.code %></code></pre>
              </div>
              <p class="mt-4 text-sm text-gray-600">Click to copy, then paste this code into your application.</p>
            </div>
          <% end %>
        <% end %>
      </div>

      <div class="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4">
        <%= for icon <- @icons do %>
          <% icon_content = read_svg_content(icon.path) %>
          <% {can_customize, _} = check_svg_customization(icon_content) %>

          <div class={"icon-card p-4 border rounded-lg text-center hover:border-blue-500 cursor-pointer #{if @current_icon == icon.path, do: "ring-2 ring-blue-500", else: ""}"}>
            <div
              class="mb-3 flex justify-center items-center h-16"
              phx-click="select_icon"
              phx-value-icon={icon.path}
            >
              <.icon name={icon.path} base_color="currentColor" class="w-10 h-10" id={"icon-card-#{icon.id}"} />
            </div>
            <p class="text-sm font-medium"><%= icon.name %></p>

            <%= if !can_customize do %>
              <div class="text-xs text-gray-500 mb-2">Not colorable</div>
            <% end %>

            <div class="mt-3 flex gap-3 justify-center">
              <button phx-click="copy-code" phx-value-format="html" phx-value-icon={icon.path}
                class="text-xs px-3 py-2 bg-gray-200 hover:bg-gray-300 rounded-md">
                HTML
              </button>
              <button phx-click="copy-code" phx-value-format="liveview" phx-value-icon={icon.path}
                class="text-xs px-3 py-2 bg-gray-200 hover:bg-gray-300 rounded-md">
                LiveView
              </button>
            </div>
          </div>
        <% end %>
      </div>

      <%= if @copied_icon && !@current_icon do %>
        <div class="mb-8 p-6 border rounded-lg bg-gray-50">
          <h3 class="text-xl font-semibold mb-4">Copied <%= String.upcase(@copied_icon.format) %> Code</h3>
          <div class="bg-white p-4 border rounded overflow-x-auto">
            <pre class="text-sm"><code><%= @copied_icon.code %></code></pre>
          </div>
          <p class="mt-4 text-sm text-gray-600">Click to copy, then paste this code into your application.</p>
        </div>
      <% end %>
    </div>
    """
  end
end
