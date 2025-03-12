defmodule IconsLvDraftWeb.IconUploadLive do
  use IconsLvDraftWeb, :live_view
  alias IconsLvDraft.Categories
  alias IconsLvDraft.SVGProcessor

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
     |> allow_upload(:icon_file,
        accept: @allowed_extensions,
        max_entries: 1,
        max_file_size: @max_file_size)

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
    {:noreply, cancel_upload(socket, :icon_file, ref)}
  end

  def handle_event("select-category", %{"category" => category_id}, socket) do
    category = Enum.find(socket.assigns.categories, &(&1.id == category_id))

    {:noreply, assign(socket, selected_category: category)}
  end

  def handle_event("save", %{"icon" => %{"name" => name}}, socket) do
    # Get upload entries
    upload_entries = socket.assigns.uploads.icon_file.entries

    if Enum.empty?(upload_entries) do
      {:noreply, assign(socket, upload_error: "Please select an SVG file to upload")}
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
          # Process the file directly without using consume_uploaded_entry
          try do
            # Find the temp file by matching entry attributes
            entry = List.first(upload_entries)

            # Get the upload UUID
            uuid = entry.uuid
            file_name = entry.client_name
            file_size = entry.client_size

            # Look for a file with that size in the temp directory
            paths = Path.wildcard("#{System.tmp_dir()}/plug-*/live_view_upload-*-*-*")
            temp_files = Enum.filter(paths, fn path ->
              stat = File.stat!(path)
              stat.size == file_size
            end)

            if Enum.empty?(temp_files) do
              {:noreply, assign(socket, upload_error: "Couldn't find uploaded file")}
            else
              # Use the first matching file (there should only be one)
              temp_file = List.first(temp_files)

              # Read SVG content
              svg_content = File.read!(temp_file)

              # Process SVG content
              processed_svg = SVGProcessor.process_svg_content(
                svg_content,
                nil,
                "currentColor",
                nil,
                nil,
                ""
              )

              # Write the processed content to the destination
              File.write!(file_path, processed_svg)

              # Redirect to get a fresh page instead of trying to reset
              socket = socket
                |> put_flash(:info, "Icon #{name} successfully uploaded to #{category_id} category")
                |> redirect(to: "/upload")

              {:noreply, socket}
            end
          rescue
            e ->
              msg = Exception.message(e)
              {:noreply, assign(socket, upload_error: "Error processing upload: #{msg}")}
          end
        end
      end
    end
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

              <div :if={Enum.empty?(@uploads.icon_file.entries)} class="text-center">
                <label for={@uploads.icon_file.ref} class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 cursor-pointer inline-block">
                  Select SVG File
                </label>
                <p class="text-sm text-gray-500 mt-2">or drag and drop your SVG file here</p>
              </div>

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
                  <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} class="text-red-500 hover:text-red-700">
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
            </div>
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
          <button type="submit" class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600">
            Upload Icon
          </button>
          <a href="/" class="px-4 py-2 bg-gray-200 text-gray-700 rounded hover:bg-gray-300">
            Cancel
          </a>
        </div>
      </form>
    </div>
    """
  end
end
