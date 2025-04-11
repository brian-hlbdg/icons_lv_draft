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
     |> assign(:svg_analysis, nil)  # Add analysis field
     |> assign(:svg_data, nil)      # Store raw SVG data
     |> assign(:standardized, nil)  # Store standardized SVG
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

  def handle_event("analyze-svg", _params, socket) do
    # Get current temporary file from upload entry
    case get_uploaded_svg_content(socket) do
      {:ok, svg_content} ->
        # Analyze and standardize the SVG
        analysis = SVGAnalyzer.analyze_svg(svg_content)
        standardized = SVGAnalyzer.standardize_svg(svg_content)

        # Update the socket with analysis results
        socket = socket
          |> assign(:svg_data, %{
              content: svg_content,
              size: byte_size(svg_content),
              filename: get_upload_filename(socket)
            })
          |> assign(:svg_analysis, analysis)
          |> assign(:standardized, standardized)

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, assign(socket, upload_error: reason)}
    end
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
          try do
            # Get SVG content - either the standardized version or original
            svg_content = case socket.assigns.standardized do
              %{optimized_svg: content} when is_binary(content) -> content
              _ ->
                # Get original content if no standardized version
                {:ok, content} = get_uploaded_svg_content(socket)
                content
            end

            # Process with SVG Processor if we haven't already standardized
            svg_content = if socket.assigns.standardized do
              svg_content  # Already processed by SVGAnalyzer
            else
              # Apply basic color processing through SVGProcessor
              SVGProcessor.process_svg_content(
                svg_content,
                nil,
                "currentColor",
                nil,
                nil,
                ""
              )
            end

            # Write the processed content to the destination
            File.write!(file_path, svg_content)

            # Create success message with standardization info
            success_message = case socket.assigns.standardized do
              %{size_reduction: reduction} when reduction > 0 ->
                "Icon #{name} successfully uploaded to #{category_id} category (optimized by #{reduction}%)"
              _ ->
                "Icon #{name} successfully uploaded to #{category_id} category"
            end

            # Redirect to get a fresh page instead of trying to reset
            socket = socket
              |> put_flash(:info, success_message)
              |> redirect(to: "/upload")

            {:noreply, socket}
          rescue
            e ->
              msg = Exception.message(e)
              {:noreply, assign(socket, upload_error: "Error processing upload: #{msg}")}
          end
        end
      end
    end
  end

  # Helper to get the currently uploaded SVG content
  defp get_uploaded_svg_content(socket) do
    case socket.assigns.uploads.icon_file.entries do
      [entry | _] ->
        # Find the temp file path
        temp_path = get_upload_temp_path(socket, entry)

        if temp_path do
          File.read(temp_path)
        else
          {:error, "Could not locate uploaded file"}
        end

      [] -> {:error, "No file uploaded"}
    end
  end

  # Helper to find the temporary path of an uploaded file
  defp get_upload_temp_path(socket, entry) do
    # Try to consume uploaded entry to get path
    consume_uploaded_entry(socket, entry, fn %{path: path} -> {:ok, path} end)
  rescue
    _ -> nil
  end

  # Helper to get the filename from current upload
  defp get_upload_filename(socket) do
    case socket.assigns.uploads.icon_file.entries do
      [entry | _] -> entry.client_name
      [] -> nil
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
                  <div class="flex space-x-2">
                    <button
                      type="button"
                      phx-click="analyze-svg"
                      class="text-sm px-3 py-1 bg-green-500 text-white rounded"
                    >
                      Analyze & Optimize
                    </button>
                    <button
                      type="button"
                      phx-click="cancel-upload"
                      phx-value-ref={entry.ref}
                      class="text-gray-400 hover:text-gray-500"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  </div>
                </div>

                <%= for err <- upload_errors(@uploads.icon_file, entry) do %>
                  <div class="text-red-500 text-xs mt-1">
                    <%= error_to_string(err) %>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Analysis Results -->
        <%= if @svg_analysis || @standardized do %>
          <div class="mb-6 bg-white border rounded-lg p-4">
            <h2 class="text-xl font-bold mb-4">SVG Analysis Results</h2>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <!-- Analysis info -->
              <div>
                <h3 class="font-medium mb-2">SVG Information</h3>
                <div class="bg-gray-50 p-4 rounded">
                  <%= if @standardized do %>
                    <div class="flex justify-between py-1 border-b">
                      <span class="font-medium">Original Size:</span>
                      <span><%= format_file_size(@standardized.original_size) %></span>
                    </div>
                    <div class="flex justify-between py-1 border-b">
                      <span class="font-medium">Optimized Size:</span>
                      <span><%= format_file_size(@standardized.optimized_size) %></span>
                    </div>
                    <div class="flex justify-between py-1 border-b">
                      <span class="font-medium">Size Reduction:</span>
                      <span class="text-green-600"><%= @standardized.size_reduction %>%</span>
                    </div>
                  <% end %>

                  <%= if @svg_analysis && @svg_analysis.viewbox do %>
                    <div class="flex justify-between py-1">
                      <span class="font-medium">ViewBox:</span>
                      <code class="bg-gray-100 px-1 rounded"><%= @svg_analysis.viewbox %></code>
                    </div>
                  <% end %>
                </div>

                <!-- Issues found -->
                <%= if @svg_analysis && @svg_analysis.issues && length(@svg_analysis.issues) > 0 do %>
                  <h3 class="font-medium mt-4 mb-2">Issues Found</h3>
                  <div class="bg-yellow-50 p-3 rounded border border-yellow-200">
                    <ul class="list-disc pl-5 text-sm">
                      <%= for issue <- @svg_analysis.issues do %>
                        <li class="text-yellow-800"><%= issue %></li>
                      <% end %>
                    </ul>
                  </div>
                <% end %>
              </div>

              <!-- Visual preview -->
              <div>
                <h3 class="font-medium mb-2">Visual Preview</h3>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <%= if @svg_data do %>
                    <div>
                      <p class="text-sm text-center mb-2">Original</p>
                      <div class="border rounded h-32 flex items-center justify-center bg-gray-50 p-4">
                        <%= Phoenix.HTML.raw(@svg_data.content) %>
                      </div>
                    </div>
                  <% end %>

                  <%= if @standardized do %>
                    <div>
                      <p class="text-sm text-center mb-2">Optimized</p>
                      <div class="border rounded h-32 flex items-center justify-center bg-gray-50 p-4">
                        <%= Phoenix.HTML.raw(@standardized.optimized_svg) %>
                      </div>
                    </div>
                  <% end %>
                </div>

                <%= if @standardized && @standardized.changes && length(@standardized.changes) > 0 do %>
                  <h3 class="font-medium mt-4 mb-2">Changes Made</h3>
                  <div class="bg-blue-50 p-3 rounded border border-blue-200 text-sm max-h-32 overflow-y-auto">
                    <ul class="list-disc pl-5">
                      <%= for change <- @standardized.changes do %>
                        <li class="text-blue-800"><%= change %></li>
                      <% end %>
                    </ul>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>

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
            class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
            disabled={Enum.empty?(@uploads.icon_file.entries)}
          >
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
