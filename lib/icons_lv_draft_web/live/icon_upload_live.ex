defmodule IconsLvDraftWeb.IconUploadLive do
  use IconsLvDraftWeb, :live_view
  alias IconsLvDraft.Categories
  alias IconsLvDraft.SVGProcessor

  def mount(_params, _session, socket) do
    categories = Categories.all()

    socket =
      socket
      |> assign(:categories, categories)
      |> assign(:selected_category, List.first(categories).id)
      |> assign(:icon_name, "")
      |> assign(:preview_svg, nil)
      |> assign(:original_svg, nil)
      |> assign(:processed_svg, nil)
      |> assign(:preprocessed_svg, nil)
      |> assign(:error_message, nil)
      |> assign(:success_message, nil)
      |> assign(:is_processing, false)  # Flag for processing state
      |> assign(:color_preview, "currentColor")  # For color preview
      |> allow_upload(:svg_file,
        accept: ~w(.svg),
        max_entries: 1,
        max_file_size: 1_000_000, # 1MB limit
        auto_upload: true,
        progress: &handle_progress/3
      )

    {:ok, socket}
  end

  def handle_event("trigger_process", _params, socket) do
    case socket.assigns.uploads.svg_file.entries do
      [entry | _] ->
        process_entry(socket, entry)
      _ ->
        {:noreply, assign(socket, :error_message, "No file to process")}
    end
  end

  defp process_entry(socket, entry) do
    # Extract the uploaded file path
    consume_uploaded_entries(socket, :svg_file, fn meta, entries ->
      uploaded_file = List.first(entries)

      # Read and process the SVG
      case File.read(meta.path) do
        {:ok, svg_content} ->
          # Preprocess the SVG for compatibility
          preprocessed_svg = SVGProcessor.preprocess_new_svg(svg_content)

          # Process SVG for preview
          processed_svg = SVGProcessor.process_svg_content(
            preprocessed_svg,
            "preview-svg",
            "currentColor",
            nil,
            nil,
            "w-full h-full",
            true
          )

          # Generate a suggested name from the file
          suggested_name = uploaded_file.client_name
            |> String.replace(~r/\.svg$/, "")
            |> String.downcase()
            |> String.replace(~r/[^a-z0-9\-\_]/, "-")
            |> String.replace(~r/-+/, "-")
            |> String.trim("-")

          # Update socket assigns
          {:ok,
            socket
            |> assign(:original_svg, svg_content)
            |> assign(:preprocessed_svg, preprocessed_svg)
            |> assign(:processed_svg, processed_svg)
            |> assign(:preview_svg, processed_svg)
            |> assign(:icon_name, suggested_name)
            |> assign(:error_message, nil)
            |> assign(:is_processing, false)
          }

        {:error, reason} ->
          {:ok, assign(socket, :error_message, "Error reading the file: #{reason}")}
      end
    end)

    {:noreply, socket}
  end

  def handle_progress(:svg_file, entry, socket) do
    if entry.done? do
      # Set processing state to true
      socket = assign(socket, :is_processing, true)

      # Extract the content from the upload
      {:noreply, consume_uploaded_entry(socket, entry, fn %{path: path} ->
        case File.read(path) do
          {:ok, svg_content} ->
            # Make sure it's valid SVG
            if valid_svg?(svg_content) do
              # Preprocess the SVG for compatibility
              preprocessed_svg = SVGProcessor.preprocess_new_svg(svg_content)

              # Process SVG for preview
              processed_svg = SVGProcessor.process_svg_content(
                preprocessed_svg,
                "preview-svg",
                "currentColor",  # base_color
                nil,             # active_color
                nil,             # warning_color
                "w-full h-full", # class
                true             # assume it supports currentColor after preprocessing
              )

              # Generate a suggested name from the file
              suggested_name = entry.client_name
                |> String.replace(~r/\.svg$/, "")
                |> String.downcase()
                |> String.replace(~r/[^a-z0-9\-\_]/, "-")
                |> String.replace(~r/-+/, "-")
                |> String.trim("-")

              # Store original, preprocessed, and processed versions
              socket
              |> assign(:original_svg, svg_content)
              |> assign(:preprocessed_svg, preprocessed_svg)
              |> assign(:processed_svg, processed_svg)
              |> assign(:preview_svg, processed_svg)
              |> assign(:icon_name, suggested_name)
              |> assign(:error_message, nil)
              |> assign(:is_processing, false)
            else
              socket
              |> assign(:error_message, "The uploaded file does not appear to be a valid SVG")
              |> assign(:is_processing, false)
            end
          {:error, reason} ->
            socket
            |> assign(:error_message, "Error reading the file: #{reason}")
            |> assign(:is_processing, false)
        end
      end)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("save_icon", %{"icon_name" => name, "category" => category}, socket) when name != "" do
    # Set processing state to true
    socket = assign(socket, :is_processing, true)

    # Sanitize the name - lowercase, replace spaces with hyphens
    sanitized_name = name
                    |> String.downcase()
                    |> String.replace(~r/[^a-z0-9\-\_]/, "-")
                    |> String.replace(~r/-+/, "-")
                    |> String.trim("-")

    # Make sure we have a processed SVG
    if socket.assigns.processed_svg do
      # Path where the icon will be saved
      icon_path = Path.join([
        Application.app_dir(:icons_lv_draft),
        "priv/static/icons",
        category,
        "#{sanitized_name}.svg"
      ])

      # Create the directory if it doesn't exist
      File.mkdir_p!(Path.dirname(icon_path))

      # Check if file already exists
      if File.exists?(icon_path) do
        {:noreply, socket
                  |> assign(:error_message, "An icon with this name already exists in the selected category")
                  |> assign(:is_processing, false)}
      else
        # Save the preprocessed SVG to the file
        # Use the cached preprocessed version if available, otherwise preprocess the original again
        preprocessed_svg = socket.assigns.preprocessed_svg || SVGProcessor.preprocess_new_svg(socket.assigns.original_svg)

        # Add a small delay to simulate processing (for demo purposes)
        # In a real app you would just process and save immediately
        Process.sleep(500)

        case File.write(icon_path, preprocessed_svg) do
          :ok ->
            socket = socket
                    |> assign(:success_message, "Icon '#{sanitized_name}' saved successfully to the #{category} category!")
                    |> assign(:icon_name, "")
                    |> assign(:preview_svg, nil)
                    |> assign(:original_svg, nil)
                    |> assign(:processed_svg, nil)
                    |> assign(:preprocessed_svg, nil)
                    |> assign(:error_message, nil)
                    |> assign(:is_processing, false)
            {:noreply, socket}

          {:error, reason} ->
            {:noreply, socket
                      |> assign(:error_message, "Error saving the file: #{reason}")
                      |> assign(:is_processing, false)}
        end
      end
    else
      {:noreply, socket
                |> assign(:error_message, "No SVG to save. Please upload an SVG file first.")
                |> assign(:is_processing, false)}
    end
  end

  def handle_event("save_icon", _params, socket) do
    {:noreply, assign(socket, :error_message, "Please provide a name for the icon")}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :svg_file, ref)}
  end

  def handle_event("select_category", %{"category" => category}, socket) do
    {:noreply, assign(socket, :selected_category, category)}
  end

  def handle_event("update_icon_name", %{"value" => name}, socket) do
    {:noreply, assign(socket, :icon_name, name)}
  end

  def handle_event("change_preview_color", %{"color" => color}, socket) do
    # Only update if we have a processed SVG
    if socket.assigns.processed_svg do
      # Re-process the SVG with the new color
      processed_svg = SVGProcessor.process_svg_content(
        socket.assigns.preprocessed_svg,
        "preview-svg",
        color,  # new base_color
        nil,    # active_color
        nil,    # warning_color
        "w-full h-full", # class
        true    # assume it supports currentColor
      )

      {:noreply,
        socket
        |> assign(:preview_svg, processed_svg)
        |> assign(:color_preview, color)}
    else
      {:noreply, socket}
    end
  end

  # Check if content is a valid SVG
  defp valid_svg?(content) do
    # Basic check - does it have svg tags and no obvious malicious content
    content =~ ~r/<svg[^>]*>/ &&
    !(content =~ ~r/<script[^>]*>/) &&
    String.length(content) > 50 &&
    String.length(content) < 1_000_000 # Extra size check
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-6">Upload New SVG Icon</h1>

      <div class="mb-8">
        <div class="flex flex-wrap gap-4 mb-6">
          <%= for category <- @categories do %>
            <button
              phx-click="select_category"
              phx-value-category={category.id}
              class={"px-4 py-2 rounded #{if @selected_category == category.id, do: "bg-blue-500 text-white", else: "bg-gray-200"}"}
            >
              <%= category.name %>
            </button>
          <% end %>
        </div>

        <form phx-submit="save_icon" phx-change="validate" class="space-y-6">
          <div class="space-y-4">
            <div>
              <label for="icon_name" class="block text-sm font-medium text-gray-700 mb-1">Icon Name</label>
              <input
                type="text"
                id="icon_name"
                name="icon_name"
                value={@icon_name}
                phx-debounce="300"
                phx-keyup="update_icon_name"
                placeholder="Enter icon name (e.g., arrow-right)"
                class="w-full px-3 py-2 border border-gray-300 rounded-md"
                required
              />
              <p class="mt-1 text-sm text-gray-500">The name will be converted to kebab-case (e.g., "Arrow Right" becomes "arrow-right")</p>
            </div>

            <input type="hidden" name="category" value={@selected_category} />

            <div class="bg-gray-50 border rounded-lg p-6">
              <label class="block text-sm font-medium text-gray-700 mb-2">Upload SVG File</label>

              <div class={"border-2 border-dashed rounded-lg p-6 #{if length(@uploads.svg_file.entries) > 0, do: "border-blue-300 bg-blue-50", else: "border-gray-300"}"}>
                <div phx-drop-target={@uploads.svg_file.ref} class="text-center">
                  <%= if length(@uploads.svg_file.entries) == 0 do %>
                    <svg xmlns="http://www.w3.org/2000/svg" class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                    </svg>
                    <p class="mt-1 text-sm text-gray-500">Drag and drop your SVG file or click to browse</p>
                    <div class="mt-4">
                      <label for={@uploads.svg_file.ref} class="cursor-pointer inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50">
                        <svg class="-ml-1 mr-2 h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13" />
                        </svg>
                        Select SVG file
                      </label>
                      <.live_file_input upload={@uploads.svg_file} class="sr-only" />
                    </div>
                  <% else %>
                    <%= for entry <- @uploads.svg_file.entries do %>
                      <div class="flex items-center justify-between bg-white p-4 rounded border mb-4">
                        <div class="flex items-center">
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-blue-500 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                          </svg>
                          <span class="text-sm font-medium"><%= entry.client_name %></span>
                        </div>
                        <div class="flex items-center">
                          <div class="text-xs text-gray-500 mr-2"><%= format_bytes(entry.client_size) %></div>
                          <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} class="text-red-500 hover:text-red-700">
                            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                            </svg>
                          </button>
                        </div>
                      </div>

                      <%= for err <- upload_errors(@uploads.svg_file, entry) do %>
                        <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
                          <%= error_to_string(err) %>
                        </div>
                      <% end %>

                      <%= if entry.done? && !@preview_svg do %>
                        <div class="bg-yellow-100 border border-yellow-400 text-yellow-700 px-4 py-3 rounded mb-4">
                          <p>File upload complete. Processing SVG...</p>
                          <div class="flex justify-center mt-2">
                            <button type="button" phx-click="trigger_process" class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600">
                              Trigger Processing
                            </button>
                          </div>
                        </div>
                      <% end %>
                    <% end %>
                  <% end %>
                </div>
              </div>

              <%= for err <- upload_errors(@uploads.svg_file) do %>
                <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mt-4">
                  <%= error_to_string(err) %>
                </div>
              <% end %>
            </div>

            <%= if @error_message do %>
              <div id="error-notification"
                phx-hook="AutoHideNotification"
                data-timeout="5000"
                class="mb-4 bg-red-100 border-l-4 border-red-500 text-red-700 p-4"
                role="alert">
                <div class="flex items-start">
                  <div class="flex-shrink-0">
                    <svg class="h-5 w-5 text-red-500" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <p class="text-sm"><%= @error_message %></p>
                  </div>
                </div>
              </div>
            <% end %>

            <%= if @success_message do %>
              <div id="success-notification"
                phx-hook="AutoHideNotification"
                data-timeout="5000"
                class="mb-4 bg-green-100 border-l-4 border-green-500 text-green-700 p-4"
                role="alert">
                <div class="flex items-start">
                  <div class="flex-shrink-0">
                    <svg class="h-5 w-5 text-green-500" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <p class="text-sm"><%= @success_message %></p>
                  </div>
                </div>
              </div>
            <% end %>

            <%= if @preview_svg do %>
              <div class="mt-8 space-y-4">
                <h3 class="text-lg font-medium">SVG Preview</h3>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
                  <div class="border rounded-lg p-6 flex flex-col">
                    <h4 class="text-sm font-medium text-gray-700 mb-4">Original SVG</h4>
                    <div class="flex-1 flex items-center justify-center bg-gray-50 p-4 rounded">
                      <%= Phoenix.HTML.raw(@original_svg) %>
                    </div>
                  </div>

                  <div class="border rounded-lg p-6 flex flex-col">
                    <div class="flex justify-between items-center mb-4">
                      <h4 class="text-sm font-medium text-gray-700">Processed SVG (uses currentColor)</h4>

                      <div class="flex items-center space-x-2">
                        <label class="text-xs text-gray-600">Preview Color:</label>
                        <div class="inline-flex rounded-md shadow-sm" role="group">
                          <button
                            type="button"
                            phx-click="change_preview_color"
                            phx-value-color="currentColor"
                            class={"px-2 py-1 text-xs font-medium rounded-l-lg border #{if @color_preview == "currentColor", do: "bg-blue-50 text-blue-700 border-blue-300", else: "bg-white text-gray-700 border-gray-300 hover:bg-gray-50"}"}
                          >
                            Current
                          </button>
                          <button
                            type="button"
                            phx-click="change_preview_color"
                            phx-value-color="#000000"
                            class={"px-2 py-1 text-xs font-medium border-t border-b #{if @color_preview == "#000000", do: "bg-blue-50 text-blue-700 border-blue-300", else: "bg-white text-gray-700 border-gray-300 hover:bg-gray-50"}"}
                          >
                            Black
                          </button>
                          <button
                            type="button"
                            phx-click="change_preview_color"
                            phx-value-color="#3B82F6"
                            class={"px-2 py-1 text-xs font-medium rounded-r-lg border #{if @color_preview == "#3B82F6", do: "bg-blue-50 text-blue-700 border-blue-300", else: "bg-white text-gray-700 border-gray-300 hover:bg-gray-50"}"}
                          >
                            Blue
                          </button>
                        </div>
                      </div>
                    </div>

                    <div
                      class="flex-1 flex items-center justify-center p-4 rounded"
                      style={"background-color: #{if @color_preview == "currentColor", do: "#f9fafb", else: if @color_preview == "#000000", do: "#f9fafb", else: lighten_color(@color_preview, 0.92)}"}
                    >
                      <div style={"color: #{if @color_preview == "currentColor", do: "currentColor", else: @color_preview}"}>
                        <%= Phoenix.HTML.raw(@preview_svg) %>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="space-y-4">
                  <p class="text-sm text-gray-600">The SVG has been processed to use currentColor for dynamic coloring and optimized for use in the icon system.</p>

                  <div class="flex gap-4">
                    <button
                      type="submit"
                      class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 flex items-center"
                      disabled={@icon_name == "" || @preview_svg == nil || @is_processing}
                    >
                      <%= if @is_processing do %>
                        <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                        </svg>
                        Processing...
                      <% else %>
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                        </svg>
                        Save Icon to Library
                      <% end %>
                    </button>

                    <button
                      type="button"
                      phx-click="cancel_upload"
                      phx-value-ref={@uploads.svg_file.entries |> List.first() |> Map.get(:ref, "")}
                      class="px-4 py-2 bg-gray-200 text-gray-700 rounded hover:bg-gray-300 flex items-center"
                      disabled={@is_processing}
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                      </svg>
                      Cancel
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </form>
      </div>
    </div>
    """
  end

  defp format_bytes(bytes) do
    cond do
      bytes < 1_024 -> "#{bytes} B"
      bytes < 1_024 * 1_024 -> "#{Float.round(bytes / 1_024, 2)} KB"
      true -> "#{Float.round(bytes / (1_024 * 1_024), 2)} MB"
    end
  end

  defp error_to_string(:too_large), do: "File is too large (max 1MB)"
  defp error_to_string(:not_accepted), do: "You can only upload SVG files (.svg)"
  defp error_to_string(:too_many_files), do: "You can only upload 1 file at a time"
  defp error_to_string(error), do: "Error uploading file: #{inspect(error)}"

  # Helper to create lighter versions of colors for backgrounds
  defp lighten_color(hex_color, factor) when is_binary(hex_color) and is_number(factor) do
    # Simple implementation that just returns a light gray
    # In a real app, you would parse the hex and calculate a lighter version
    "#f0f9ff"  # Light blue background
  end
end
