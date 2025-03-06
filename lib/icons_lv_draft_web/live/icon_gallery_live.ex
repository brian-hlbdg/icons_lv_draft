defmodule IconsLvDraftWeb.IconGalleryLive do
  use IconsLvDraftWeb, :live_view
  import Phoenix.HTML, only: [raw: 1]  # Import raw for rendering SVG safely

  alias IconsLvDraft.Categories
  alias IconsLvDraft.SVGProcessor

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
      show_color_options: false
    )

    # Don't use temporary_assigns for icons
    {:ok, socket}
  end

  def handle_event("select_icon", %{"icon" => icon_path}, socket) do
    # Process the SVG to make IDs unique
    preview_svg = case process_icon_svg(icon_path, socket.assigns) do
      {:ok, svg} -> svg
      {:error, _} -> nil
    end

    # When an icon is selected, set current_icon and processed SVG
    {:noreply, assign(socket,
      current_icon: icon_path,
      processed_svg: preview_svg
    )}
  end

  def handle_event("toggle_copy_options", _params, socket) do
    # Toggle color customization options
    {:noreply, assign(socket, show_color_options: !socket.assigns.show_color_options)}
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

    socket =
      case color_type do
        "base" -> assign(socket, base_color: value)
        "active" -> assign(socket, active_color: value)
        "warning" -> assign(socket, warning_color: value)
      end

    # Update the processed SVG with new colors
    preview_svg = if socket.assigns.current_icon do
      case process_icon_svg(socket.assigns.current_icon, socket.assigns) do
        {:ok, svg} -> svg
        {:error, _} -> nil
      end
    else
      nil
    end

    socket = assign(socket, processed_svg: preview_svg)

    {:noreply, socket}
  end

  def handle_event("copy-code", %{"format" => format, "icon" => icon_path}, socket) do
    %{base_color: base_color, active_color: active_color, warning_color: warning_color} = socket.assigns

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

    {:noreply, assign(socket, copied_icon: %{path: icon_path, code: code, format: format})}
  end

  def handle_event("close-copied-notification", _params, socket) do
    {:noreply, assign(socket, copied_icon: nil)}
  end

  # Process the SVG to make IDs unique and apply colors
  defp process_icon_svg(icon_path, assigns) do
    %{base_color: base_color, active_color: active_color, warning_color: warning_color} = assigns

    # Create a unique prefix using the icon name
    [_category, name] = String.split(icon_path, "/", parts: 2)
    prefix = "icon-#{String.replace(name, ".", "-")}"

    case SVGProcessor.process_svg_file(icon_path, prefix) do
      {:ok, svg_content} ->
        # Apply colors to the processed SVG
        svg_content = apply_colors_to_svg(svg_content, base_color, active_color, warning_color)
        {:ok, svg_content}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Apply colors to the SVG content
  defp apply_colors_to_svg(svg_content, base_color, active_color, warning_color) do
    # Replace currentColor with the specified base color
    svg_content = if base_color && base_color != "currentColor" do
      String.replace(svg_content, "fill=\"currentColor\"", "fill=\"#{base_color}\"")
    else
      svg_content
    end

    # Add style element with custom properties if needed
    if active_color || warning_color do
      # Extract closing svg tag
      case Regex.run(~r/(.*?)(<\/svg>)$/, svg_content, capture: :all_but_first) do
        [content, closing] ->
          # Build style tag with variables
          style_tag = "<style>"
          style_tag = if active_color, do: style_tag <> " :root { --active-color: #{active_color}; }", else: style_tag
          style_tag = if warning_color, do: style_tag <> " :root { --warning-color: #{warning_color}; }", else: style_tag
          style_tag = style_tag <> "</style>"

          # Insert style before closing svg tag
          content <> style_tag <> closing

        _ -> svg_content
      end
    else
      svg_content
    end
  end

  def render(assigns) do
    ~H"""
    <div>
      <!-- Search section -->
      <form phx-change="search" class="mb-6 p-4 bg-gray-50 rounded-lg">
        <div class="w-full">
          <label for="search_term" class="block text-sm font-medium text-gray-700 mb-1">Search Icons</label>
          <div class="flex items-center">
            <input
              type="text"
              name="search[term]"
              value={@search_term}
              placeholder="Search icons..."
              class="flex-1 px-3 py-2 border border-gray-300 rounded-md"
            />
            <%= if @current_icon do %>
              <button
                type="button"
                phx-click="toggle_copy_options"
                class="ml-4 px-4 py-2 bg-blue-100 text-blue-700 rounded-md font-medium text-sm hover:bg-blue-200"
              >
                <%= if @show_color_options do %>
                  Hide Customization Options
                <% else %>
                  Show Customization Options
                <% end %>
              </button>
            <% end %>
          </div>
        </div>
      </form>

      <!-- Preview Panel - Shows immediately when an icon is selected -->
      <%= if @current_icon do %>
        <div class="mb-6 p-6 bg-white border rounded-lg shadow-sm">
          <div class="flex flex-col md:flex-row items-start md:items-center gap-6">
            <!-- Icon Preview - Using the fixed SVG with unique IDs -->
            <div class="bg-gray-50 p-4 rounded-lg border shadow-sm w-full md:w-64 h-64 flex items-center justify-center">
              <%= if @processed_svg do %>
                <!-- Render the processed SVG with unique IDs -->
                <div class="w-32 h-32 flex items-center justify-center">
                  <%= raw(@processed_svg) %>
                </div>
              <% else %>
                <!-- Fallback if SVG processing failed -->
                <div class="text-center">
                  <div class="w-32 h-32 bg-white rounded-full shadow-sm flex items-center justify-center mx-auto">
                    <div class="text-2xl font-medium text-gray-700">
                      <%= String.split(@current_icon, "/", parts: 2) |> List.last() |> String.split(".") |> List.first() |> String.slice(0, 2) |> String.upcase() %>
                    </div>
                  </div>
                  <p class="mt-4 text-sm font-medium text-gray-700">
                    <%= String.split(@current_icon, "/", parts: 2) |> List.last() |> String.split(".") |> List.first() |> String.replace("-", " ") |> String.capitalize() %>
                  </p>
                </div>
              <% end %>
            </div>

            <!-- Copy Options -->
            <div class="flex-1">
              <h3 class="text-lg font-semibold mb-3">
                Icon Options
              </h3>

              <!-- Color Options - Only shown when toggled -->
              <div class={!@show_color_options && "hidden"}>
                <div class="mb-4">
                  <div class="space-y-3">
                    <div>
                      <label for="base_color" class="block text-sm font-medium text-gray-700 mb-1">Base Color</label>
                      <input
                        type="text"
                        name="base_color"
                        value={@base_color}
                        placeholder="e.g., #000000, currentColor"
                        phx-change="update-color"
                        phx-value-color_type="base"
                        class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm"
                      />
                    </div>

                    <div>
                      <label for="active_color" class="block text-sm font-medium text-gray-700 mb-1">Active Color (optional)</label>
                      <input
                        type="text"
                        name="active_color"
                        value={@active_color}
                        placeholder="e.g., #0066cc"
                        phx-change="update-color"
                        phx-value-color_type="active"
                        class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm"
                      />
                    </div>

                    <div>
                      <label for="warning_color" class="block text-sm font-medium text-gray-700 mb-1">Warning Color (optional)</label>
                      <input
                        type="text"
                        name="warning_color"
                        value={@warning_color}
                        placeholder="e.g., #ff0000"
                        phx-change="update-color"
                        phx-value-color_type="warning"
                        class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm"
                      />
                    </div>
                  </div>
                </div>
              </div>

              <!-- Copy Buttons - Always shown -->
              <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mt-4">
                <button
                  class="px-4 py-2 rounded text-sm font-medium flex items-center justify-center bg-blue-500 text-white hover:bg-blue-600"
                  phx-click="copy-code"
                  phx-value-format="html"
                  phx-value-icon={@current_icon}
                >
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                  </svg>
                  Copy HTML Code
                </button>
                <button
                  class="px-4 py-2 rounded text-sm font-medium flex items-center justify-center bg-indigo-500 text-white hover:bg-indigo-600"
                  phx-click="copy-code"
                  phx-value-format="liveview"
                  phx-value-icon={@current_icon}
                >
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                  Copy LiveView Code
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Icons Grid -->
      <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
        <%= for icon <- @icons do %>
          <div class={[
            "icon-card p-4 border rounded-lg text-center hover:border-blue-500 cursor-pointer transition-all",
            @current_icon == icon.path && "ring-2 ring-blue-500 bg-blue-50"
          ]}>
            <div
              class="mb-3 flex justify-center items-center h-16"
              phx-click="select_icon"
              phx-value-icon={icon.path}
            >
              <.icon name={icon.path} class="w-10 h-10" />
            </div>
            <p class="text-sm font-medium"><%= icon.name %></p>
          </div>
        <% end %>
      </div>

      <!-- Code Copied Modal -->
      <%= if @copied_icon do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div class="bg-white p-6 rounded-lg shadow-xl max-w-2xl w-full">
            <div class="flex justify-between items-center mb-4">
              <h3 class="text-xl font-semibold">Code Copied!</h3>
              <button phx-click="close-copied-notification" class="text-gray-500 hover:text-gray-700">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            <div class="bg-gray-50 p-4 rounded-lg overflow-x-auto mb-4">
              <pre class="text-sm"><code><%= @copied_icon.code %></code></pre>
            </div>
            <p class="text-sm text-gray-600">The code has been copied to your clipboard.</p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
