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
      current_icon: nil
    )

    {:ok, socket, temporary_assigns: [icons: []]}
  end

  def handle_event("select_icon", %{"icon" => icon_path}, socket) do
    {:noreply, assign(socket, current_icon: icon_path)}
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

    # In a real app, you'd use JS interop to copy to clipboard
    # For now, we'll just show what's been "copied"
    {:noreply, assign(socket, copied_icon: %{path: icon_path, code: code, format: format})}
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

        <div class="flex flex-wrap gap-6 mb-8">
          <div>
            <label for="base_color" class="block text-sm font-medium text-gray-700 mb-1">Base Color</label>
            <input type="text" name="base_color" value={@base_color} placeholder="e.g., #000000, currentColor"
              phx-change="update-color" phx-value-color_type="base"
              class="w-full px-3 py-2 border border-gray-300 rounded-md" />
          </div>

          <div>
            <label for="active_color" class="block text-sm font-medium text-gray-700 mb-1">Active Color (optional)</label>
            <input type="text" name="active_color" value={@active_color} placeholder="e.g., #0066cc"
              phx-change="update-color" phx-value-color_type="active"
              class="w-full px-3 py-2 border border-gray-300 rounded-md" />
          </div>

          <div>
            <label for="warning_color" class="block text-sm font-medium text-gray-700 mb-1">Warning Color (optional)</label>
            <input type="text" name="warning_color" value={@warning_color} placeholder="e.g., #ff0000"
              phx-change="update-color" phx-value-color_type="warning"
              class="w-full px-3 py-2 border border-gray-300 rounded-md" />
          </div>
        </div>
      </div>

      <div class="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-4 gap-4">
        <%= for icon <- @icons do %>
          <!-- In your icon card section of the template -->
            <div class={"icon-card p-4 border rounded-lg text-center hover:border-blue-500 cursor-pointer #{if @current_icon == icon.path, do: "ring-2 ring-blue-500", else: ""}"}>
              <div
                class="mb-3 flex justify-center items-center h-16"
                phx-click="select_icon"
                phx-value-icon={icon.path}
              >
                <.icon name={icon.path} base_color={@base_color} active_color={@active_color} warning_color={@warning_color} class="w-10 h-10" />
              </div>
              <p class="text-sm font-medium"><%= icon.name %></p>
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



      <%= if @copied_icon do %>
        <div class="mt-8 p-6 border rounded-lg bg-gray-50">
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
