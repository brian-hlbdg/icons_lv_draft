defmodule IconsLvDraftWeb.IconGalleryLive do
  use IconsLvDraftWeb, :live_view

  alias IconsLvDraft.Categories
  alias IconsLvDraft.SVGProcessor
  alias IconsLvDraftWeb.Components.ColorPicker

  def mount(_params, _session, socket) do
    categories = Categories.all()

    # Add virtual "All" category
    all_category = Categories.get_all_category()

    socket = assign(socket,
      categories: [all_category | categories],
      current_category: all_category,
      icons: [],
      base_color: "currentColor",
      active_color: nil,
      warning_color: nil,
      search_term: nil,
      copied_icon: nil,
      current_icon: nil,
      processed_svg: nil,
      current_svg_info: nil,
      show_color_options: false,  # Set to false by default
      is_all_category: false      # Track if we're showing all icons
    )

    # Remove temporary assigns for icons to ensure they stay in the DOM
    {:ok, socket}
  end

  def handle_event("select_icon", %{"icon" => icon_path}, socket) do
    # Read the original SVG to extract its color information
    [category, name] = String.split(icon_path, "/", parts: 2)
    icon_file = Application.app_dir(:icons_lv_draft, "priv/static/icons/#{category}/#{name}.svg")

    svg_info = with {:ok, svg_content} <- File.read(icon_file) do
      # Check if it uses currentColor
      has_current_color = String.contains?(svg_content, "currentColor")

      # Extract the main color if it doesn't use currentColor
      main_color = if !has_current_color do
        SVGProcessor.extract_main_color(svg_content)
      else
        nil
      end

      # Return the info
      %{
        has_current_color: has_current_color,
        main_color: main_color
      }
    else
      _ -> %{has_current_color: true, main_color: nil}
    end

    # Update base color if a main color was detected
    socket = if svg_info.main_color && svg_info.main_color != "currentColor" do
      assign(socket, base_color: svg_info.main_color)
    else
      socket
    end

    # Process SVG with appropriate colors
    processed_svg = process_icon_svg(
      icon_path,
      "selected-icon-preview",
      base_color: socket.assigns.base_color,
      active_color: socket.assigns.active_color,
      warning_color: socket.assigns.warning_color,
      has_current_color: svg_info.has_current_color
    )

    {:noreply, assign(socket,
      current_icon: icon_path,
      processed_svg: processed_svg,
      current_svg_info: svg_info,
      show_color_options: false  # Always hide color options when selecting a new icon
    )}
  end

  def handle_params(%{"category" => category_id}, _uri, socket) do
    category = Categories.get_category(category_id)
    icons = Categories.list_icons(category_id)

    socket = assign(socket,
      current_category: category,
      icons: icons,
      page_title: "#{category.name} Icons",
      is_all_category: false
    )

    {:noreply, socket}
  end

  def handle_params(_params, _uri, %{assigns: %{live_action: :all}} = socket) do
    all_category = Categories.get_all_category()
    icons = Categories.list_all_icons()

    socket = assign(socket,
      current_category: all_category,
      icons: icons,
      page_title: "All Icons",
      is_all_category: true
    )

    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    %{id: category_id} = List.first(socket.assigns.categories)
    icons = Categories.list_icons(category_id)

    socket = assign(socket,
      icons: icons,
      page_title: "Icon Gallery",
      is_all_category: false
    )

    {:noreply, socket}
  end

  def handle_event("search", %{"search" => %{"term" => term}}, socket) do
    %{current_category: current_category, is_all_category: is_all_category} = socket.assigns

    icons =
      if term == "" do
        if is_all_category do
          Categories.list_all_icons()
        else
          Categories.list_icons(current_category.id)
        end
      else
        term_lower = String.downcase(term)

        if is_all_category do
          Categories.list_all_icons()
          |> Enum.filter(fn icon ->
            String.contains?(String.downcase(icon.name), term_lower) ||
            (Map.has_key?(icon, :category_name) &&
             String.contains?(String.downcase(icon.category_name), term_lower))
          end)
        else
          Categories.list_icons(current_category.id)
          |> Enum.filter(&String.contains?(String.downcase(&1.name), term_lower))
        end
      end

    {:noreply, assign(socket, icons: icons, search_term: term)}
  end

  def handle_event("update-color", params, socket) do
    # Handle both direct color picker events and text input changes
    {color_type, value} = cond do
      # Handle direct pushEvent from JS hook
      Map.has_key?(params, "color") && Map.has_key?(params, "value") ->
        {params["color"], params["value"]}

      # Handle direct color clicks
      Map.has_key?(params, "value-color") && Map.has_key?(params, "value-value") ->
        {params["value-color"], params["value-value"]}

      # Handle form changes from text input
      Map.has_key?(params, "value-color") ->
        field_name = "color-" <> params["value-color"]
        {params["value-color"], params[field_name]}

      # Handle standard form changes
      true ->
        # Find the color field - key should start with "color-"
        color_field = params |> Map.keys() |> Enum.find(fn k -> String.starts_with?(k, "color-") end)
        if color_field do
          color_type = String.replace_prefix(color_field, "color-", "")
          {color_type, params[color_field]}
        else
          # Fallback for unexpected format
          {"base", nil}
        end
    end

    # Process the value (keep named colors as is)
    value = cond do
      value == "" -> nil
      value == "currentColor" -> "currentColor"
      String.starts_with?(value, "#") -> value
      true -> value  # This allows named colors like "red", "blue", etc.
    end

    # Update the color in the socket assigns
    socket = case color_type do
      "base" -> assign(socket, base_color: value)
      "active" -> assign(socket, active_color: value)
      "warning" -> assign(socket, warning_color: value)
      _ -> socket
    end

    # If there's a currently selected icon, update the processed SVG
    socket = if socket.assigns.current_icon do
      # Get the SVG info
      has_current_color = if socket.assigns[:current_svg_info],
        do: socket.assigns.current_svg_info.has_current_color,
        else: true

      # Process the SVG with this info
      processed_svg = process_icon_svg(
        socket.assigns.current_icon,
        "selected-icon-preview",
        base_color: socket.assigns.base_color,
        active_color: socket.assigns.active_color,
        warning_color: socket.assigns.warning_color,
        has_current_color: has_current_color
      )
      assign(socket, processed_svg: processed_svg)
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
      # Get SVG info for the new icon
      [category, name] = String.split(icon_path, "/", parts: 2)
      icon_file = Application.app_dir(:icons_lv_draft, "priv/static/icons/#{category}/#{name}.svg")

      svg_info = with {:ok, svg_content} <- File.read(icon_file) do
        %{
          has_current_color: String.contains?(svg_content, "currentColor"),
          main_color: SVGProcessor.extract_main_color(svg_content)
        }
      else
        _ -> %{has_current_color: true, main_color: nil}
      end

      # Process the SVG
      processed_svg = process_icon_svg(
        icon_path,
        "selected-icon-preview",
        base_color: socket.assigns.base_color,
        active_color: socket.assigns.active_color,
        warning_color: socket.assigns.warning_color,
        has_current_color: svg_info.has_current_color
      )

      assign(socket,
        current_icon: icon_path,
        processed_svg: processed_svg,
        current_svg_info: svg_info
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
    {:noreply, assign(socket, current_icon: nil, processed_svg: nil, current_svg_info: nil, show_color_options: false)}
  end

  # Process an icon SVG file with the current color settings
  defp process_icon_svg(icon_path, element_id, opts \\ []) do
    # Get the colors from options or use the defaults
    opts = Keyword.merge([
      base_color: "currentColor",
      active_color: nil,
      warning_color: nil,
      class: "w-full h-full",
      size: "64px",  # Add default size for preview
      has_current_color: true  # Default to assuming currentColor
    ], opts)

    # Process the SVG with the correct has_current_color flag
    with [category, name] <- String.split(icon_path, "/", parts: 2),
         icon_file <- Application.app_dir(:icons_lv_draft, "priv/static/icons/#{category}/#{name}.svg"),
         {:ok, svg_content} <- File.read(icon_file) do

      SVGProcessor.process_svg_content(
        svg_content,
        element_id,
        opts[:base_color],
        opts[:active_color],
        opts[:warning_color],
        opts[:class],
        opts[:has_current_color]
      )
      |> SVGProcessor.ensure_width_height_attrs(opts[:size])
    else
      _ -> nil
    end
  end

  # In Phoenix 1.7, the template is in a separate function
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-3xl font-bold mb-6">IconsLv Gallery</h1>

      <div class="mb-8 flex flex-wrap gap-4">
        <%= for category <- @categories do %>
          <.link
            navigate={if category.id == "all", do: ~p"/all", else: ~p"/category/#{category.id}"}
            class={"px-4 py-2 rounded #{if @current_category.id == category.id, do: "bg-blue-500 text-white", else: "bg-gray-200"}"}
          >
            <%= category.name %>
          </.link>
        <% end %>
      </div>

      <div class="mb-8">
        <h2 class="text-2xl font-semibold mb-4"><%= @current_category.name %></h2>
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

            <%= if @current_svg_info && !@current_svg_info.has_current_color do %>
              <div class="mb-4 p-3 bg-yellow-50 border border-yellow-300 rounded text-yellow-800 text-sm">
                <div class="flex items-start">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2 mt-0.5 flex-shrink-0" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                  </svg>
                  <div>
                    <p class="font-medium">This SVG does not use currentColor</p>
                    <p class="mt-1">The detected color <%= @current_svg_info.main_color || "could not be determined" %> has been selected for you.</p>
                  </div>
                </div>
              </div>
            <% end %>

            <%= if @show_color_options do %>
              <div class="mb-4 p-4 bg-gray-50 border rounded-lg">
                <div class="flex justify-between items-center mb-3">
                  <h4 class="text-sm font-medium text-gray-700">Color Customization</h4>

                  <%= if @current_svg_info do %>
                    <div class="flex items-center text-xs text-gray-500">
                      <span class={"inline-block w-2 h-2 rounded-full mr-1 #{if @current_svg_info.has_current_color, do: "bg-green-500", else: "bg-yellow-500"}"}></span>
                      <%= if @current_svg_info.has_current_color do %>
                        <span>Supports dynamic colors</span>
                      <% else %>
                        <span>Uses fixed colors</span>
                      <% end %>
                    </div>
                  <% end %>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <ColorPicker.color_picker
                    id="base-color-picker"
                    value={@base_color}
                    label="Base Color"
                    color_type="base"
                    placeholder="e.g., #000000, currentColor"
                  />

                  <ColorPicker.color_picker
                    id="active-color-picker"
                    value={@active_color}
                    label="Active Color (optional)"
                    color_type="active"
                    placeholder="e.g., #0066cc"
                  />

                  <ColorPicker.color_picker
                    id="warning-color-picker"
                    value={@warning_color}
                    label="Warning Color (optional)"
                    color_type="warning"
                    placeholder="e.g., #ff0000"
                  />
                </div>

                <%= if @current_svg_info && @current_svg_info.main_color && @current_svg_info.main_color != "currentColor" do %>
                  <div class="mt-4 pt-4 border-t border-gray-200">
                    <h5 class="text-xs font-medium text-gray-600 mb-2">Original Color:</h5>
                    <div class="flex flex-wrap gap-2">
                      <div
                        class="flex items-center px-2 py-1 rounded bg-gray-100 text-xs cursor-pointer hover:bg-gray-200"
                        phx-click="update-color"
                        phx-value-color="base"
                        phx-value-value={@current_svg_info.main_color}
                      >
                        <div
                          class="w-3 h-3 rounded-sm mr-1 border border-gray-300"
                          style={"background-color: #{@current_svg_info.main_color}"}
                        ></div>
                        <%= @current_svg_info.main_color %>
                      </div>
                      <div
                        class="flex items-center px-2 py-1 rounded bg-gray-100 text-xs cursor-pointer hover:bg-gray-200"
                        phx-click="update-color"
                        phx-value-color="base"
                        phx-value-value="currentColor"
                      >
                        <div class="w-3 h-3 rounded-sm mr-1 border border-gray-300 bg-gradient-to-br from-white to-black"></div>
                        currentColor
                      </div>
                    </div>
                  </div>
                <% end %>
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
          <div class={"icon-card p-4 border rounded-lg text-center hover:border-blue-500 cursor-pointer #{if @current_icon == icon.path, do: "ring-2 ring-blue-500", else: ""}"}>
            <div
              class="mb-3 flex justify-center items-center h-16"
              phx-click="select_icon"
              phx-value-icon={icon.path}
            >
              <.icon name={icon.path} base_color={@base_color} active_color={@active_color} warning_color={@warning_color} class="w-10 h-10" id={"icon-card-#{icon.id}"} />
            </div>
            <div>
              <p class="text-sm font-medium"><%= icon.name %></p>
              <%= if @is_all_category && Map.has_key?(icon, :category_name) do %>
                <p class="text-xs text-gray-500 mt-1"><%= icon.category_name %></p>
              <% end %>
            </div>
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
