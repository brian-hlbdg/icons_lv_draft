defmodule IconsLvDraftWeb.IconUploadLive do
  use IconsLvDraftWeb, :live_view
  alias IconsLvDraft.Categories
  alias IconsLvDraft.SVGProcessor
  alias IconsLvDraft.SVGAnalyzer

  @allowed_extensions ~w(.svg)
  @max_file_size 1_000_000 # 1MB

  def mount(_params, _session, socket) do
    categories = Categories.all()

    socket = socket
     |> assign(:categories, categories)
     |> assign(:selected_category, List.first(categories))
     |> assign(:icon_name, "")
     |> assign(:kebab_name, "")
     |> assign(:upload_error, nil)
     |> assign(:upload_success, nil)
     |> assign(:svg_data, nil)
     |> assign(:svg_analysis, nil)
     |> assign(:standardized, nil)
     |> assign(:analyzing, false)
     |> assign(:ready_to_upload, false)
     |> allow_upload(:icon_file,
        accept: @allowed_extensions,
        max_entries: 1,
        max_file_size: @max_file_size,
        auto_upload: true,
        reset_on_cancel: false,
        progress: &handle_progress/3)

    # Check for flash messages from redirects
    socket = if socket.assigns.flash[:info] do
      assign(socket, upload_success: socket.assigns.flash[:info])
    else
      socket
    end

    {:ok, socket}
  end

  def handle_event("validate", %{"icon" => %{"name" => name}}, socket) do
    kebab_name = name_to_kebab_case(name)

    {:noreply, assign(socket, icon_name: name, kebab_name: kebab_name)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    # Reset analysis data when canceling an upload
    socket = socket
      |> cancel_upload(:icon_file, ref)
      |> assign(:svg_data, nil)
      |> assign(:svg_analysis, nil)
      |> assign(:standardized, nil)
      |> assign(:ready_to_upload, false)

    {:noreply, socket}
  end

  def handle_event("select-category", %{"category" => category_id}, socket) do
    category = Enum.find(socket.assigns.categories, &(&1.id == category_id))

    {:noreply, assign(socket, selected_category: category)}
  end

  def handle_event("reset-file", _params, socket) do
    {:noreply, socket
      |> assign(:svg_data, nil)
      |> assign(:svg_analysis, nil)
      |> assign(:standardized, nil)
      |> assign(:ready_to_upload, false)
      |> allow_upload(:icon_file,
        accept: @allowed_extensions,
        max_entries: 1,
        max_file_size: @max_file_size,
        auto_upload: true,
        reset_on_cancel: false,
        progress: &handle_progress/3)
    }
  end

  def handle_event("save", %{"icon" => %{"name" => name}}, socket) do
    # Only proceed if we've analyzed the file and it's ready to upload
    if !socket.assigns.ready_to_upload do
      {:noreply, assign(socket, upload_error: "Please analyze the SVG file first")}
    else
      category_id = socket.assigns.selected_category.id
      kebab_name = name_to_kebab_case(name)

      # Validate name
      if kebab_name == "" do
        {:noreply, assign(socket, upload_error: "Icon name cannot be empty")}
      else
        # Create destination directory
        dest_path = Application.app_dir(:icons_lv_draft, "priv/static/icons/#{category_id}")
        File.mkdir_p!(dest_path)

        # Create destination file path
        file_path = Path.join(dest_path, "#{kebab_name}.svg")

        # Check if file already exists
        if File.exists?(file_path) do
          {:noreply, assign(socket, upload_error: "An icon with this name already exists in this category")}
        else
          # Use the standardized version if available, or the original content
          svg_content = if socket.assigns.standardized do
            socket.assigns.standardized.optimized_svg
          else
            socket.assigns.svg_data.content
          end

          # Write the content to the destination
          case File.write(file_path, svg_content) do
            :ok ->
              # Redirect to get a fresh page
              socket = socket
                |> put_flash(:info, "Icon #{name} successfully uploaded to #{category_id} category")
                |> redirect(to: "/upload")
              {:noreply, socket}

            {:error, reason} ->
              {:noreply, assign(socket, upload_error: "Error writing file: #{reason}")}
          end
        end
      end
    end
  end

  defp handle_progress(:icon_file, entry, socket) when entry.done? do
    # Set analyzing state
    socket = assign(socket, :analyzing, true)

    # Use a custom path lookup approach to find the file without consuming it
    # This uses Phoenix LiveView's internal storage pattern
    upload_config = socket.assigns.uploads.icon_file
    path = Path.join(
      upload_config.tmp_dir,
      "#{upload_config.ref}-#{entry.ref}-#{entry.client_name}"
    )

    case File.read(path) do
      {:ok, file_content} ->
        # Analyze the SVG
        analysis = SVGAnalyzer.analyze_svg(file_content)

        # Standardize the SVG
        standardized = SVGAnalyzer.standardize_svg(file_content)

        # Update socket with analysis results
        socket = socket
          |> assign(:svg_data, %{
            filename: entry.client_name,
            content: file_content,
            size: entry.client_size
          })
          |> assign(:svg_analysis, analysis)
          |> assign(:standardized, standardized)
          |> assign(:analyzing, false)
          |> assign(:ready_to_upload, true)
          |> assign(:upload_error, nil)  # Clear any previous errors

        {:noreply, socket}

      {:error, reason} ->
        socket = socket
          |> assign(:analyzing, false)
          |> assign(:upload_error, "Failed to read SVG file: #{reason}")

        {:noreply, socket}
    end
  end

  defp handle_progress(:icon_file, _entry, socket) do
    {:noreply, socket}
  end

  # Convert a string to kebab-case
  defp name_to_kebab_case(name) do
    name
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")  # Remove special chars except spaces and hyphens
    |> String.replace(~r/\s+/, "-")          # Replace spaces with hyphens
    |> String.replace(~r/-+/, "-")           # Replace multiple hyphens with single hyphen
  end

  # Format file size to human readable format
  defp format_file_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_file_size(bytes) when bytes < 1024*1024 do
    kb = bytes / 1024
    "#{:erlang.float_to_binary(kb, [decimals: 1])} KB"
  end
  defp format_file_size(bytes) do
    mb = bytes / (1024*1024)
    "#{:erlang.float_to_binary(mb, [decimals: 1])} MB"
  end

  # Convert error atoms to user-friendly messages
  defp error_to_string(:too_large), do: "File is too large (max 1MB)"
  defp error_to_string(:not_accepted), do: "File type not accepted. Please upload an SVG file"
  defp error_to_string(:too_many_files), do: "Too many files"
  defp error_to_string(err), do: "Error: #{err}"

  # Add a link for navigation in the icon gallery
  def upload_button(assigns) do
    ~H"""
    <.link navigate={~p"/upload"} class="inline-flex items-center px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600">
      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
      </svg>
      Upload New Icon
    </.link>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto p-6">
      <h1 class="text-3xl font-bold mb-6">Upload New SVG Icon</h1>

      <div class="flex space-x-2 mb-6">
        <%= for category <- @categories do %>
          <button
            phx-click="select-category"
            phx-value-category={category.id}
            class={"px-4 py-2 rounded #{if @selected_category.id == category.id, do: "bg-blue-500 text-white", else: "bg-gray-200"}"}
          >
            <%= category.name %>
          </button>
        <% end %>
      </div>

      <form phx-submit="save" phx-change="validate">
        <div class="mb-6">
          <label for="icon_name" class="block font-medium mb-2">Icon Name</label>
          <input
            type="text"
            id="icon_name"
            name="icon[name]"
            value={@icon_name}
            class="w-full px-3 py-2 border border-gray-300 rounded-md"
            placeholder="Enter icon name (e.g., Arrow Right)"
          />
          <p class="text-sm text-gray-600 mt-1">
            The name will be converted to kebab-case
            <%= if @kebab_name != "", do: "(e.g., \"#{@icon_name}\" becomes \"#{@kebab_name}\")" %>
          </p>
        </div>

        <div class="mb-6">
          <label class="block font-medium mb-2">Upload SVG File</label>
          <div class="border-2 border-dashed border-gray-300 rounded-lg p-6 bg-gray-50">
            <div phx-drop-target={@uploads.icon_file.ref} class="space-y-4">
              <.live_file_input upload={@uploads.icon_file} class="hidden" />

              <%= if Enum.empty?(@uploads.icon_file.entries) and !@svg_data do %>
                <div class="text-center">
                  <label for={@uploads.icon_file.ref} class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 cursor-pointer inline-block">
                    Select SVG File
                  </label>
                  <p class="text-sm text-gray-500 mt-2">or drag and drop your SVG file here</p>
                </div>
              <% end %>

              <%= for entry <- @uploads.icon_file.entries do %>
                <div class="flex items-center justify-between bg-white p-4 rounded border">
                  <div class="flex items-center">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-blue-500 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                    <div>
                      <p class="font-medium"><%= entry.client_name %></p>
                      <p class="text-sm text-gray-500"><%= format_file_size(entry.client_size) %></p>
                    </div>
                  </div>
                  <button
                    type="button"
                    phx-click="cancel-upload"
                    phx-value-ref={entry.ref}
                    class="text-red-500 hover:text-red-700"
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                    </svg>
                  </button>
                </div>

                <!-- Error display for this specific entry -->
                <%= for err <- upload_errors(@uploads.icon_file, entry) do %>
                  <div class="text-red-500 text-sm mt-1">
                    <%= error_to_string(err) %>
                  </div>
                <% end %>
              <% end %>

              <!-- Show file info after analysis if entries become empty -->
              <%= if Enum.empty?(@uploads.icon_file.entries) and @svg_data do %>
                <div class="flex items-center justify-between bg-white p-4 rounded border">
                  <div class="flex items-center">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-blue-500 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                    <div>
                      <p class="font-medium"><%= @svg_data.filename %></p>
                      <p class="text-sm text-gray-500"><%= format_file_size(@svg_data.size) %></p>
                    </div>
                  </div>
                  <button
                    type="button"
                    phx-click="reset-file"
                    class="text-red-500 hover:text-red-700"
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                    </svg>
                  </button>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Analyzing indicator -->
        <div :if={@analyzing} class="mb-6 p-4 bg-blue-50 border border-blue-200 rounded-md">
          <div class="flex items-center">
            <svg class="animate-spin h-5 w-5 mr-3 text-blue-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <span class="text-blue-700">Analyzing SVG file...</span>
          </div>
        </div>

        <!-- General validation errors -->
        <div :if={@upload_error} class="mb-6 p-4 bg-red-50 border border-red-200 rounded-md text-red-600">
          <%= @upload_error %>
        </div>

        <!-- Success message -->
        <div :if={@upload_success} class="mb-6 p-4 bg-green-50 border border-green-200 rounded-md text-green-600">
          <%= @upload_success %>
        </div>

        <div class="flex space-x-4">
          <button
            type="submit"
            class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed"
            disabled={!@ready_to_upload || @analyzing}
          >
            Upload Icon
          </button>
          <a href="/" class="px-4 py-2 bg-gray-200 text-gray-700 rounded hover:bg-gray-300">
            Cancel
          </a>
        </div>
      </form>

      <%= if @svg_data && @svg_analysis do %>
        <div class="mt-8 border rounded-lg overflow-hidden">
          <div class="bg-white p-4 border-b">
            <h2 class="text-lg font-semibold">SVG Analysis Results</h2>
            <%= if @ready_to_upload do %>
              <p class="text-green-600 text-sm mt-1">✓ SVG ready to upload</p>
            <% end %>
          </div>
          <div class="p-4 bg-gray-50">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <h3 class="font-medium mb-2">File Information</h3>
                <div class="bg-white p-3 rounded border mb-4">
                  <p><strong>Filename:</strong> <%= @svg_data.filename %></p>
                  <p><strong>Size:</strong> <%= format_file_size(@svg_data.size) %></p>
                  <%= if @svg_analysis.viewbox do %>
                    <p><strong>ViewBox:</strong> <%= @svg_analysis.viewbox %></p>
                  <% end %>
                </div>

                <h3 class="font-medium mb-2">Elements</h3>
                <div class="bg-white p-3 rounded border">
                  <ul class="space-y-1">
                    <%= for {element, count} <- @svg_analysis.elements do %>
                      <%= if count > 0 do %>
                        <li><code>&lt;<%= element %>&gt;</code>: <%= count %></li>
                      <% end %>
                    <% end %>
                  </ul>
                </div>
              </div>

              <div>
                <%= if @svg_analysis.issues && length(@svg_analysis.issues) > 0 do %>
                  <h3 class="font-medium mb-2">Issues Found</h3>
                  <div class="bg-yellow-50 p-3 rounded border border-yellow-200 mb-4">
                    <ul class="list-disc pl-5">
                      <%= for issue <- @svg_analysis.issues do %>
                        <li class="text-yellow-800"><%= issue %></li>
                      <% end %>
                    </ul>
                  </div>
                <% end %>

                <%= if @standardized && @standardized.changes && length(@standardized.changes) > 0 do %>
                  <h3 class="font-medium mb-2">Improvements Made</h3>
                  <div class="bg-blue-50 p-3 rounded border border-blue-200">
                    <ul class="list-disc pl-5">
                      <%= for change <- @standardized.changes do %>
                        <li class="text-blue-800"><%= change %></li>
                      <% end %>
                    </ul>
                    <%= if @standardized.size_reduction > 0 do %>
                      <p class="mt-2 text-green-700 font-medium">
                        Size reduced by <%= @standardized.size_reduction %>%
                        (<%= format_file_size(@standardized.optimized_size) %>)
                      </p>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>

            <%= if @standardized do %>
              <div class="mt-6 grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <h3 class="font-medium mb-2">Original SVG</h3>
                  <div class="bg-white p-4 rounded border h-40 flex items-center justify-center overflow-hidden">
                    <%= Phoenix.HTML.raw(@svg_data.content) %>
                  </div>
                </div>
                <div>
                  <h3 class="font-medium mb-2">Optimized SVG</h3>
                  <div class="bg-white p-4 rounded border h-40 flex items-center justify-center overflow-hidden">
                    <%= Phoenix.HTML.raw(@standardized.optimized_svg) %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
