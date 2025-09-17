defmodule PhoebeWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use PhoebeWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar">
      <div class="nav-container">
        <.link navigate={~p"/"} class="nav-brand">
          <span class="brand-text">Phoebe</span>
        </.link>

        <nav class="nav-links">
          <.link navigate={~p"/expressions"} class="nav-link">Browse</.link>
          <a href="/api/v1" class="nav-link">API</a>
        </nav>
      </div>
    </header>

    <main>
      {render_slot(@inner_block)}
    </main>

    <footer class="footer">
      <div class="footer-content">
        <p>&copy; 2024 Phoebe - A minimal G-Expression repository</p>
        <div class="footer-links">
          <a href="/api/v1">API Documentation</a>
          <a href="https://github.com/json-g/json_ge_lib">G-Expression Spec</a>
        </div>
      </div>
    </footer>

    <.flash_group flash={@flash} />

    <style>
      .navbar {
        background: white;
        border-bottom: 1px solid #e2e8f0;
        padding: 0 20px;
        position: sticky;
        top: 0;
        z-index: 50;
      }

      .nav-container {
        max-width: 1200px;
        margin: 0 auto;
        display: flex;
        justify-content: space-between;
        align-items: center;
        height: 64px;
      }

      .nav-brand {
        text-decoration: none;
        font-size: 1.5rem;
        font-weight: 700;
        color: #667eea;
      }

      .brand-text {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        background-clip: text;
      }

      .nav-links {
        display: flex;
        gap: 24px;
      }

      .nav-link {
        text-decoration: none;
        color: #4a5568;
        font-weight: 500;
        padding: 8px 16px;
        border-radius: 6px;
        transition: all 0.2s;
      }

      .nav-link:hover {
        background: #f7fafc;
        color: #667eea;
      }

      .footer {
        background: #2d3748;
        color: white;
        padding: 40px 20px;
        margin-top: 80px;
      }

      .footer-content {
        max-width: 1200px;
        margin: 0 auto;
        display: flex;
        justify-content: space-between;
        align-items: center;
      }

      .footer-links {
        display: flex;
        gap: 24px;
      }

      .footer-links a {
        color: #a0aec0;
        text-decoration: none;
        transition: color 0.2s;
      }

      .footer-links a:hover {
        color: white;
      }

      @media (max-width: 768px) {
        .footer-content {
          flex-direction: column;
          gap: 20px;
          text-align: center;
        }

        .nav-container {
          padding: 0 16px;
        }

        .nav-links {
          gap: 16px;
        }
      }
    </style>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end
end
