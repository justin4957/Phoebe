defmodule PhoebeWeb.HomeLive do
  use PhoebeWeb, :live_view

  alias Phoebe.Repository

  @impl true
  def mount(_params, _session, socket) do
    recent_expressions =
      Repository.list_g_expressions()
      |> Enum.take(6)

    total_count = length(Repository.list_g_expressions())

    {:ok,
     socket
     |> assign(:recent_expressions, recent_expressions)
     |> assign(:total_count, total_count)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="swiss-home">
      <div class="swiss-hero">
        <h1>PHOEBE</h1>
        <p class="swiss-subtitle">A MINIMAL PACKAGE REPOSITORY FOR JSON G-EXPRESSIONS</p>
        <div class="swiss-stats">
          <div class="stat-item">
            <span class="stat-number">{@total_count}</span>
            <span class="stat-label">EXPRESSIONS</span>
          </div>
        </div>
        <div class="swiss-actions">
          <.link navigate={~p"/expressions"} class="swiss-btn swiss-btn-primary">
            BROWSE EXPRESSIONS
          </.link>
          <a href="/api/v1" class="swiss-btn swiss-btn-secondary">API DOCUMENTATION</a>
        </div>
      </div>

      <div class="swiss-content">
        <div class="swiss-section">
          <h2>RECENT G-EXPRESSIONS</h2>
          <div class="swiss-expression-grid">
            <div :for={expression <- @recent_expressions} class="swiss-expression-card">
              <.link navigate={~p"/expressions/#{expression.name}"} class="swiss-expression-link">
                <h3>{expression.title}</h3>
                <p class="swiss-expression-name">@{expression.name}</p>
                <p class="swiss-expression-description">{expression.description}</p>
                <div class="swiss-expression-meta">
                  <span>{expression.downloads_count} DOWNLOADS</span>
                </div>
              </.link>
            </div>
          </div>
        </div>

        <div class="swiss-section">
          <h2>ABOUT G-EXPRESSIONS</h2>
          <div class="swiss-feature-grid">
            <div class="swiss-feature-card">
              <h3>FUNCTIONAL PROGRAMMING</h3>
              <p>
                JSON G-Expressions provide a structured way to represent functional programming constructs in JSON format.
              </p>
            </div>
            <div class="swiss-feature-card">
              <h3>LANGUAGE AGNOSTIC</h3>
              <p>
                Use G-Expressions across different programming languages and platforms with consistent semantics.
              </p>
            </div>
            <div class="swiss-feature-card">
              <h3>COMPOSABLE</h3>
              <p>
                Build complex expressions from simple primitives like literals, references, applications, and lambda functions.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
