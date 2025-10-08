defmodule PhoebeWeb.ExpressionLive.Show do
  use PhoebeWeb, :live_view

  alias Phoebe.Repository

  @impl true
  def mount(%{"name" => name}, _session, socket) do
    case Repository.get_g_expression_with_versions(name) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "G-Expression not found")
         |> redirect(to: ~p"/expressions")}

      expression ->
        Repository.increment_downloads(expression)

        {:ok,
         socket
         |> assign(:expression, expression)
         |> assign(:selected_version, get_latest_version(expression))}
    end
  end

  @impl true
  def handle_event("select_version", %{"version" => version_string}, socket) do
    selected_version =
      Enum.find(socket.assigns.expression.versions, &(&1.version == version_string))

    {:noreply, assign(socket, :selected_version, selected_version)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="swiss-expression-show">
      <div class="swiss-expression-header">
        <h1>{@expression.title}</h1>
        <p class="swiss-package-name">@{@expression.name}</p>
        <div class="swiss-stats-row">
          <span class="swiss-stat-item">{@expression.downloads_count} DOWNLOADS</span>
          <span class="swiss-stat-item">{length(@expression.versions)} VERSIONS</span>
        </div>
      </div>

      <div class="swiss-expression-content">
        <div class="swiss-info-panel">
          <div class="swiss-info-section">
            <h2>DESCRIPTION</h2>
            <p>{@expression.description}</p>
          </div>

          <%= if @expression.tags != [] do %>
            <div class="swiss-info-section">
              <h2>TAGS</h2>
              <div class="swiss-tags">
                <span :for={tag <- @expression.tags} class="swiss-tag">{tag}</span>
              </div>
            </div>
          <% end %>

          <div class="swiss-info-section">
            <h2>VERSION SELECTOR</h2>
            <div class="swiss-version-selector">
              <select phx-change="select_version" name="version" class="swiss-select">
                <option
                  :for={version <- @expression.versions}
                  value={version.version}
                  selected={@selected_version && @selected_version.version == version.version}
                >
                  {version.version} - {Calendar.strftime(version.inserted_at, "%B %d, %Y")}
                </option>
              </select>
            </div>
          </div>
        </div>

        <div class="swiss-code-panel">
          <h2>G-EXPRESSION</h2>
          <%= if @selected_version do %>
            <div class="swiss-code-block">
              <pre><code class="language-json"><%= Jason.encode!(@selected_version.expression_data, pretty: true) %></code></pre>
            </div>
            <div class="swiss-code-meta">
              <div class="swiss-meta-item">
                <span class="swiss-meta-label">VERSION</span>
                <span class="swiss-meta-value">{@selected_version.version}</span>
              </div>
              <div class="swiss-meta-item">
                <span class="swiss-meta-label">CHECKSUM</span>
                <span class="swiss-meta-value swiss-monospace">{@selected_version.checksum}</span>
              </div>
              <div class="swiss-meta-item">
                <span class="swiss-meta-label">PUBLISHED</span>
                <span class="swiss-meta-value">
                  {Calendar.strftime(@selected_version.inserted_at, "%B %d, %Y at %I:%M %p")}
                </span>
              </div>
            </div>
          <% else %>
            <p class="swiss-no-data">No versions available</p>
          <% end %>
        </div>
      </div>

      <div class="swiss-api-section">
        <h2>API USAGE</h2>
        <div class="swiss-code-examples">
          <div class="swiss-code-example">
            <h3>DOWNLOAD THIS G-EXPRESSION</h3>
            <div class="swiss-code-block">
              <pre><code>curl "http://localhost:4000/api/v1/expressions/<%= @expression.name %>"</code></pre>
            </div>
          </div>

          <%= if @selected_version do %>
            <div class="swiss-code-example">
              <h3>DOWNLOAD SPECIFIC VERSION</h3>
              <div class="swiss-code-block">
                <pre><code>curl "http://localhost:4000/api/v1/expressions/<%= @expression.name %>/versions/<%= @selected_version.version %>"</code></pre>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp get_latest_version(%{versions: []}), do: nil
  defp get_latest_version(%{versions: [latest | _]}), do: latest
end
