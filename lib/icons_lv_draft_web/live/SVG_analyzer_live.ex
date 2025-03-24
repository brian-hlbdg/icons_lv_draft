defmodule IconsLvDraftWeb.SVGAnalyzerLive do
  use IconsLvDraftWeb, :live_view
  alias IconsLvDraft.SVGAnalyzer
  alias IconsLvDraft.SVGPathConverter
  alias IconsLvDraftWeb.Components.SVGUpload

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "SVG Analyzer")
     |> assign(:svg_data, nil)
     |> assign(:analysis, nil)
     |> assign(:standardized, nil)
     |> allow_upload(:svg,
       accept: ~w(.svg),
       max_entries: 1,
       max_file_size: 5_000_000,
       auto_upload: true,
       progress: &handle_progress/3
     )}
  end

  @impl true
  def handle_event("validate-upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :svg, ref)}
  end

  @impl true
  def handle_event("process-svg", _params, socket) do
    # Will be handled by the handle_progress callback
    {:noreply, socket}
  end

  @impl true
  def handle_event("download-standardized", _params, socket) do
    case socket.assigns.standardized do
      %{optimized_svg: svg_content} when is_binary(svg_content) ->
        {:noreply,
         push_event(socket, "download-svg", %{
           content: svg_content,
           filename: "standardized.svg"
         })}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("copy-optimized-svg", _params, socket) do
    case socket.assigns.standardized do
      %{optimized_svg: svg_content} when is_binary(svg_content) ->
        {:noreply, push_event(socket, "copy-to-clipboard", %{content: svg_content})}

      _ ->
        {:noreply, socket}
    end
  end

  # Process the uploaded file when it completes
  defp handle_progress(:svg, entry, socket) do
    if entry.done? do
      # Consume the uploaded entry
      consumed_socket = consume_uploaded_entry(socket, entry, fn %{path: path} ->
        # Read the SVG file
        case File.read(path) do
          {:ok, svg_content} ->
            # Analyze the SVG
            analysis = SVGAnalyzer.analyze_svg(svg_content)
            # Standardize the SVG
            standardized = SVGAnalyzer.standardize_svg(svg_content)

            # Update socket with analysis and standardized SVG
            {:ok, %{
              svg_data: %{
                filename: entry.client_name,
                content: svg_content,
                size: byte_size(svg_content)
              },
              analysis: analysis,
              standardized: standardized
            }}

          {:error, reason} ->
            # Handle file read error
            {:ok, %{
              error: "Failed to read SVG file: #{reason}"
            }}
        end
      end)

      socket = case consumed_socket.assigns do
        %{error: error} ->
          socket
          |> put_flash(:error, error)
          |> assign(:svg_data, nil)
          |> assign(:analysis, nil)
          |> assign(:standardized, nil)

        %{svg_data: svg_data, analysis: analysis, standardized: standardized} ->
          socket
          |> assign(:svg_data, svg_data)
          |> assign(:analysis, analysis)
          |> assign(:standardized, standardized)
      end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto py-8 px-4" id="svg-analyzer-container" phx-hook="SVGDownloader">
      <div class="mb-8">
        <h1 class="text-3xl font-bold">SVG Analyzer & Standardizer</h1>
        <p class="text-gray-600 mt-2">
          Upload your SVG to analyze and standardize it according to modern best practices.
        </p>
      </div>

      <div class="grid grid-cols-1 gap-8">
        <!-- Upload Section -->
        <div class="bg-white border rounded-lg shadow-sm overflow-hidden">
          <div class="p-6 border-b">
            <h2 class="text-lg font-medium">Upload SVG</h2>
            <p class="text-gray-500 text-sm mt-1">
              Upload an SVG file to analyze its structure and convert outdated elements to modern standards.
            </p>
          </div>
          <div class="p-6">
            <SVGUpload.svg_upload id="svg-upload" upload={@uploads.svg} />
          </div>
        </div>

        <%= if @svg_data do %>
          <!-- Results Section -->
          <div class="bg-white border rounded-lg shadow-sm overflow-hidden">
            <div class="p-6 border-b">
              <div class="flex justify-between items-center">
                <h2 class="text-lg font-medium">Results for <%= @svg_data.filename %></h2>
                <%= if @standardized do %>
                  <div class="flex space-x-3">
                    <button
                      phx-click="copy-optimized-svg"
                      class="inline-flex items-center px-3 py-1.5 border border-gray-300 text-sm leading-5 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:border-blue-300 focus:shadow-outline-blue"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3" />
                      </svg>
                      Copy SVG
                    </button>
                    <button
                      phx-click="download-standardized"
                      class="inline-flex items-center px-3 py-1.5 border border-transparent text-sm leading-5 font-medium rounded-md text-white bg-blue-600 hover:bg-blue-500 focus:outline-none focus:border-blue-700 focus:shadow-outline-blue"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                      </svg>
                      Download
                    </button>
                  </div>
                <% end %>
              </div>
            </div>

            <div class="p-6 grid grid-cols-1 md:grid-cols-2 gap-8">
              <!-- Original vs Optimized -->
              <div>
                <h3 class="text-base font-medium mb-3">File Information</h3>
                <div class="bg-gray-50 p-4 rounded-md">
                  <table class="w-full text-sm text-left text-gray-600">
                    <tbody>
                      <tr class="border-b border-gray-200">
                        <td class="py-2 font-medium">Original Size</td>
                        <td class="py-2"><%= format_file_size(@svg_data.size) %></td>
                      </tr>
                      <%= if @standardized do %>
                        <tr class="border-b border-gray-200">
                          <td class="py-2 font-medium">Optimized Size</td>
                          <td class="py-2"><%= format_file_size(@standardized.optimized_size) %></td>
                        </tr>
                        <tr class="border-b border-gray-200">
                          <td class="py-2 font-medium">Size Reduction</td>
                          <td class="text-green-600">
                            <%= @standardized.size_reduction %>%
                          </td>
                        </tr>
                      <% end %>
                      <%= if @analysis && @analysis.viewbox do %>
                        <tr>
                          <td class="py-2 font-medium">ViewBox</td>
                          <td class="py-2"><code class="bg-gray-100 px-1.5 py-0.5 rounded text-gray-800"><%= @analysis.viewbox %></code></td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>

                <!-- Element Analysis -->
                <%= if @analysis && @analysis.elements do %>
                  <h3 class="text-base font-medium mb-3 mt-6">Element Types</h3>
                  <div class="bg-gray-50 p-4 rounded-md max-h-64 overflow-y-auto">
                    <table class="w-full text-sm text-gray-600">
                      <thead>
                        <tr class="text-left border-b border-gray-200">
                          <th class="py-2 font-medium">Element</th>
                          <th class="py-2 font-medium">Count</th>
                        </tr>
                      </thead>
                      <tbody>
                        <%= for {element, count} <- Enum.filter(@analysis.elements, fn {_k, v} -> v > 0 end) |> Enum.sort() do %>
                          <tr class="border-b border-gray-200">
                            <td class="py-2">
                              <code class="bg-gray-100 px-1.5 py-0.5 rounded text-gray-800">&lt;<%= element %>&gt;</code>
                            </td>
                            <td class="py-2"><%= count %></td>
                          </tr>
                        <% end %>
                        <%= if Enum.all?(@analysis.elements, fn {_k, v} -> v == 0 end) do %>
                          <tr>
                            <td class="py-2 text-gray-500 italic" colspan="2">No elements found</td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                <% end %>

                <!-- Issues Found -->
                <%= if @analysis && @analysis.issues && length(@analysis.issues) > 0 do %>
                  <h3 class="text-base font-medium mb-3 mt-6">Issues Found</h3>
                  <div class="bg-yellow-50 p-4 rounded-md border border-yellow-200">
                    <ul class="list-disc pl-5 space-y-1 text-sm text-yellow-800">
                      <%= for issue <- @analysis.issues do %>
                        <li><%= issue %></li>
                      <% end %>
                    </ul>
                  </div>
                <% end %>
              </div>

              <!-- Standardization Changes -->
              <%= if @standardized && @standardized.changes && length(@standardized.changes) > 0 do %>
                <div>
                  <h3 class="text-base font-medium mb-3">Standardization Changes</h3>
                  <div class="bg-blue-50 p-4 rounded-md border border-blue-200 max-h-96 overflow-y-auto">
                    <ul class="list-disc pl-5 space-y-2 text-sm text-blue-800">
                      <%= for change <- @standardized.changes do %>
                        <li><%= change %></li>
                      <% end %>
                    </ul>
                  </div>

                  <!-- Code Preview -->
                  <h3 class="text-base font-medium mb-3 mt-6">Optimized SVG Preview</h3>
                  <div class="border rounded-md overflow-hidden">
                    <div class="bg-gray-100 px-4 py-2 text-xs font-mono text-gray-500 border-b">
                      standardized.svg
                    </div>
                    <div class="p-4 bg-gray-50 max-h-72 overflow-y-auto">
                      <pre class="text-xs text-gray-800 whitespace-pre-wrap"><code><%= @standardized.optimized_svg %></code></pre>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Visual Preview -->
      <%= if @svg_data do %>
        <div class="mt-8 bg-white border rounded-lg shadow-sm overflow-hidden">
          <div class="p-6 border-b">
            <h2 class="text-lg font-medium">Visual Comparison</h2>
          </div>
          <div class="p-6 grid grid-cols-1 md:grid-cols-2 gap-8">
            <div>
              <h3 class="text-base font-medium mb-3">Original SVG</h3>
              <div class="border rounded-md p-6 flex items-center justify-center bg-gray-50 h-64">
                <%= Phoenix.HTML.raw(@svg_data.content) %>
              </div>
            </div>
            <%= if @standardized do %>
              <div>
                <h3 class="text-base font-medium mb-3">Standardized SVG</h3>
                <div class="border rounded-md p-6 flex items-center justify-center bg-gray-50 h-64">
                  <%= Phoenix.HTML.raw(@standardized.optimized_svg) %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions
  defp format_file_size(bytes) when is_integer(bytes) do
    cond do
      bytes < 1024 -> "#{bytes} B"
      bytes < 1024 * 1024 -> "#{Float.round(bytes / 1024, 2)} KB"
      true -> "#{Float.round(bytes / (1024 * 1024), 2)} MB"
    end
  end
end
