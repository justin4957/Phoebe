defmodule PhoebeWeb.ExpressionLive.Index do
  use PhoebeWeb, :live_view

  alias Phoebe.Repository

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:search_query, "")
     |> assign(:expressions, Repository.list_g_expressions())
     |> assign(:loading, false)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    search_query = params["search"] || ""

    expressions =
      if search_query != "" do
        Repository.search_g_expressions(search_query)
      else
        Repository.list_g_expressions()
      end

    {:noreply,
     socket
     |> assign(:search_query, search_query)
     |> assign(:expressions, expressions)}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    {:noreply, push_patch(socket, to: ~p"/expressions?#{%{search: query}}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-header">
      <h1>G-Expressions</h1>
      <p>Browse and search available G-Expression packages</p>
    </div>

    <div class="search-section">
      <.form for={%{}} as={:search} phx-submit="search" class="search-form">
        <.input
          name="query"
          type="search"
          placeholder="Search G-Expressions..."
          value={@search_query}
          class="search-input"
        />
        <button type="submit" class="btn btn-primary">Search</button>
      </.form>
    </div>

    <div class="results-section">
      <%= if @search_query != "" do %>
        <p class="search-results">
          Found {length(@expressions)} results for "{@search_query}"
        </p>
      <% end %>

      <div class="expression-list">
        <div :for={expression <- @expressions} class="expression-item">
          <.link navigate={~p"/expressions/#{expression.name}"} class="expression-link">
            <div class="expression-header">
              <h3 class="expression-title">{expression.title}</h3>
              <span class="expression-name">@{expression.name}</span>
            </div>
            <p class="expression-description">{expression.description}</p>
            <div class="expression-meta">
              <div class="tags">
                <span :for={tag <- expression.tags} class="tag">{tag}</span>
              </div>
              <div class="stats">
                <span class="downloads">{expression.downloads_count} downloads</span>
              </div>
            </div>
          </.link>
        </div>

        <%= if @expressions == [] do %>
          <div class="empty-state">
            <%= if @search_query != "" do %>
              <h3>No expressions found</h3>
              <p>No G-Expressions match your search query.</p>
              <.link navigate={~p"/expressions"} class="btn btn-secondary">
                View All Expressions
              </.link>
            <% else %>
              <h3>No expressions available</h3>
              <p>There are no G-Expressions in the repository yet.</p>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
