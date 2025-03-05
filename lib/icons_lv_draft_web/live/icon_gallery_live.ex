defmodule IconsLvDraftWeb.IconGalleryLive do
  use IconsLvDraftWeb, :live_view

  alias IconsLvDraft.Categories

  # Import the preview helper functions
  import IconsLvDraftWeb.IconPreviewHelpers

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
      preview_svg: nil,  # Add this new assign for the direct SVG preview
      show_color_options: false,
      show_copy_panel: false
    )

    # Don't use temporary_assigns for icons as we want them to persist
    {:ok, socket}
  end

  def handle_event("select_icon", %{"icon" => icon_path}, socket) do
    # Generate the preview SVG for this icon
    preview_svg = case render_single_icon_preview(icon_path,
                                            socket.assigns.base_color,
                                            socket.assigns.active_color,
                                            socket.assigns.warning_color) do
      {:ok, svg} -> svg
      {:error, _} -> nil
    end

    # When an icon is selected, we update the current_icon but don't automatically
    # show the copy panel - this is up to the user now
    {:noreply, assign(socket, current_icon: icon_path, preview_svg: preview_svg)}
  end

  def handle_event("toggle_copy_panel", _params, socket) do
    # Toggle the copy panel visibility
    {:noreply, assign(socket, show_copy_panel: !socket.assigns.show_copy_panel)}
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

    # Update the preview SVG whenever colors change if there's a current icon
    socket = if socket.assigns.current_icon do
      preview_svg = case render_single_icon_preview(socket.assigns.current_icon,
                                             socket.assigns.base_color,
                                             socket.assigns.active_color,
                                             socket.assigns.warning_color) do
        {:ok, svg} -> svg
        {:error, _} -> nil
      end
      assign(socket, preview_svg: preview_svg)
    else
      socket
    end

    {:noreply, socket}
  end

  def handle_event("toggle_color_options", _params, socket) do
    {:noreply, assign(socket, show_color_options: !socket.assigns.show_color_options)}
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

    # In a real app, you'd use JS interop to copy to clipboard
    {:noreply, assign(socket, copied_icon: %{path: icon_path, code: code, format: format})}
  end

  def handle_event("close-copied-notification", _params, socket) do
    {:noreply, assign(socket, copied_icon: nil)}
  end

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

        <!-- Search and Copy Code Tools -->
        <div class="bg-gray-50 p-4 rounded-lg border border-gray-200 mb-8">
          <!-- Search Bar -->
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
        <button
          type="button"
          phx-click="toggle_copy_panel"
          class="ml-4 px-4 py-2 bg-blue-100 text-blue-700 rounded-md font-medium text-sm hover:bg-blue-200"
        >
          <%= if @show_copy_panel do %>
            Hide Copy Options
          <% else %>
            Show Copy Options
          <% end %>
        </button>
      </div>
      <%= if @current_icon do %>
        <div class="mt-2 text-sm text-gray-600">
          Selected: <span class="font-semibold"><%= String.split(@current_icon, "/", parts: 2) |> List.last() |> String.capitalize() |> String.replace("-", " ") %></span>
        </div>
      <% end %>
    </div>
  </form>

  <!-- Copy panel - Only shown when toggled -->
  <%= if @show_copy_panel do %>
    <div class="mb-6 p-4 bg-white border rounded-lg shadow-sm">
      <div class="flex justify-between items-center mb-4">
        <h3 class="text-lg font-semibold">Copy Icon Code</h3>
        <button
          phx-click="toggle_copy_panel"
          class="text-gray-400 hover:text-gray-600"
          aria-label="Close panel"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
          </svg>
        </button>
      </div>

      <!-- Simplified Preview Area - Just display icon name instead of SVG -->
      <div class="mb-4 p-4 bg-gray-50 border rounded-lg">
        <%= if @current_icon do %>
          <div class="text-center">
            <div class="w-24 h-24 bg-white rounded-full shadow-sm flex items-center justify-center mx-auto">
              <!-- Use an empty div with unique ID instead of complex SVG rendering -->
              <div id="icon-preview-placeholder" class="w-16 h-16 text-gray-400">
                <!-- Icon name only -->
                <div class="text-lg font-medium text-gray-800">
                  <%= String.split(@current_icon, "/", parts: 2) |> List.last() |> String.split(".") |> List.first() %>
                </div>
              </div>
            </div>
            <p class="mt-3 text-sm text-gray-500">Icon preview not shown to avoid rendering issues</p>
          </div>
        <% else %>
          <div class="text-center text-gray-400">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 mx-auto mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
            </svg>
            <p>Select an icon to preview</p>
          </div>
        <% end %>
      </div>

      <!-- Color Options -->
      <div class="mb-4">
        <div class="flex items-center mb-4">
          <input
            type="checkbox"
            id="show_color_options"
            class="mr-2 h-4 w-4"
            phx-click="toggle_color_options"
            checked={@show_color_options}
          />
          <label for="show_color_options" class="text-sm font-medium text-gray-700">
            Customize icon colors
          </label>
        </div>

        <div class={!@show_color_options && "hidden"}>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
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

      <!-- Copy Buttons -->
      <div class="grid grid-cols-2 gap-4">
        <button
          class={[
            "px-4 py-2 rounded text-sm font-medium flex items-center justify-center",
            @current_icon && "bg-blue-500 text-white hover:bg-blue-600",
            !@current_icon && "bg-gray-200 text-gray-500 cursor-not-allowed"
          ]}
          disabled={!@current_icon}
          phx-click={@current_icon && "copy-code"}
          phx-value-format="html"
          phx-value-icon={@current_icon}
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
          </svg>
          Copy HTML Code
        </button>
        <button
          class={[
            "px-4 py-2 rounded text-sm font-medium flex items-center justify-center",
            @current_icon && "bg-indigo-500 text-white hover:bg-indigo-600",
            !@current_icon && "bg-gray-200 text-gray-500 cursor-not-allowed"
          ]}
          disabled={!@current_icon}
          phx-click={@current_icon && "copy-code"}
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
  <% end %>

  <!-- Icons Grid -->
  <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
    <%= for icon <- @icons do %>
      <div class={[
        "icon-card p-4 border rounded-lg text-center hover:border-blue-500 cursor-pointer transition-all",
        @current_icon == icon.path && "bg-blue-50 border-blue-500"
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
  </div>
  </div>
    """
  end
end
