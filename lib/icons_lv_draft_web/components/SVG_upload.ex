defmodule IconsLvDraftWeb.Components.SVGUpload do
  use Phoenix.Component
  import Phoenix.HTML.Form
  import IconsLvDraftWeb.CoreComponents
  alias Phoenix.LiveView.JS

  @doc """
  Renders an SVG upload component.

  ## Examples

      <.svg_upload upload={@uploads.svg} />

  """
  attr :id, :string, required: true
  attr :upload, :map, required: true
  attr :max_file_size, :integer, default: 5 * 1_024 * 1_024  # 5 MB default
  attr :rest, :global

  def svg_upload(assigns) do
    ~H"""
    <div id={@id} class="svg-upload-container" {@rest}>
      <div id={"#{@id}-dropzone"} phx-hook="SVGUploadZone" class="p-6 border-2 border-dashed border-gray-300 rounded-lg bg-gray-50">
        <div class="flex flex-col items-center justify-center">
          <svg xmlns="http://www.w3.org/2000/svg" class="w-12 h-12 mb-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
          </svg>
          <p class="mb-2 text-sm text-gray-600">
            <span class="font-medium">Click to upload</span> or drag and drop
          </p>
          <p class="text-xs text-gray-500">SVG only, max file size: <%= format_file_size(@max_file_size) %></p>
        </div>

        <.form for={%{}} phx-change="validate-upload" phx-submit="process-svg" class="mt-4">
          <!-- Key change: Make the file input accessible via data attribute -->
          <div>
            <.live_file_input upload={@upload} class="hidden" id={"#{@id}-input"} />
          </div>

          <div class="w-full flex justify-center">
            <button
              type="button"
              id={"#{@id}-button"}
              class="mt-2 inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              Select SVG File
            </button>
          </div>
        </.form>

        <div id={"#{@id}-preview"} class="mt-4">
          <%= for entry <- @upload.entries do %>
            <div class="relative bg-white p-4 border rounded-md">
              <div class="flex items-center justify-between mb-2">
                <div class="flex items-center">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-gray-500 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                  <span class="text-sm font-medium"><%= entry.client_name %></span>
                </div>

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

              <div class="relative w-full h-2 bg-gray-200 rounded-full overflow-hidden">
                <div class="bg-blue-600 h-full transition-all duration-300 ease-out" style={"width: #{entry.progress}%"}></div>
              </div>

              <%= for err <- upload_errors(@upload, entry) do %>
                <div class="text-red-500 text-xs mt-1">
                  <%= error_to_string(err) %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions for the upload component
  defp format_file_size(bytes) do
    cond do
      bytes < 1_024 -> "#{bytes} B"
      bytes < 1_024 * 1_024 -> "#{div(bytes, 1_024)} KB"
      bytes < 1_024 * 1_024 * 1_024 -> "#{div(bytes, 1_024 * 1_024)} MB"
      true -> "#{div(bytes, 1_024 * 1_024 * 1_024)} GB"
    end
  end

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:too_many_files), do: "Too many files uploaded"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(err), do: "Error: #{inspect(err)}"
end
