defmodule PhoebeWeb.ApiDocsLive do
  use PhoebeWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="api-docs">
      <div class="api-hero">
        <h1>PHOEBE API</h1>
        <p class="api-subtitle">A COMPREHENSIVE INTERFACE FOR G-EXPRESSION MANAGEMENT</p>
      </div>

      <div class="api-content">
        <div class="api-section">
          <h2>GETTING STARTED</h2>
          <p>The Phoebe API provides programmatic access to G-Expression packages. All endpoints return JSON and follow RESTful conventions.</p>

          <div class="api-tutorial-links">
            <h3>TUTORIALS</h3>
            <ul class="tutorial-list">
              <li>
                <a href="#publishing-tutorial" class="tutorial-link">
                  <strong>PUBLISHING G-EXPRESSIONS</strong>
                  <span>Learn how to submit your G-Expression packages to the repository</span>
                </a>
              </li>
              <li>
                <a href="#integration-tutorial" class="tutorial-link">
                  <strong>API INTEGRATION</strong>
                  <span>Integrate Phoebe into your development workflow</span>
                </a>
              </li>
              <li>
                <a href="#validation-tutorial" class="tutorial-link">
                  <strong>G-EXPRESSION VALIDATION</strong>
                  <span>Understand the validation rules and expression format</span>
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div class="api-section">
          <h2>BASE URL</h2>
          <div class="code-sample">
            <code>http://localhost:4000/api/v1</code>
          </div>
        </div>

        <div class="api-section">
          <h2>ENDPOINTS</h2>

          <div class="endpoint-group">
            <h3>LIST G-EXPRESSIONS</h3>
            <div class="endpoint-details">
              <div class="method-url">
                <span class="method get">GET</span>
                <span class="url">/expressions</span>
              </div>
              <p>Retrieve all G-Expressions with optional search filtering.</p>
            </div>
          </div>

          <div class="endpoint-group">
            <h3>CREATE G-EXPRESSION</h3>
            <div class="endpoint-details">
              <div class="method-url">
                <span class="method post">POST</span>
                <span class="url">/expressions</span>
              </div>
              <p>Submit a new G-Expression to the repository.</p>
            </div>
          </div>

          <div class="endpoint-group">
            <h3>GET G-EXPRESSION</h3>
            <div class="endpoint-details">
              <div class="method-url">
                <span class="method get">GET</span>
                <span class="url">/expressions/&#123;name&#125;</span>
              </div>
              <p>Retrieve a specific G-Expression with all its versions.</p>
            </div>
          </div>
        </div>

        <div class="api-section">
          <h2 id="publishing-tutorial">PUBLISHING TUTORIAL</h2>
          <div class="tutorial-content">
            <h3>STEP 1 - PREPARE YOUR G-EXPRESSION</h3>
            <p>Ensure your G-Expression follows the JSON G-Expression specification. All expressions must have a valid structure with 'g' (type) and 'v' (value) properties.</p>

            <h3>STEP 2 - VALIDATE LOCALLY</h3>
            <p>Test your G-Expression structure before publishing. Phoebe supports these expression types:</p>
            <ul>
              <li><code>lit</code> - Literal values</li>
              <li><code>ref</code> - Variable references</li>
              <li><code>app</code> - Function applications</li>
              <li><code>vec</code> - Vectors/arrays</li>
              <li><code>lam</code> - Lambda functions</li>
              <li><code>fix</code> - Fixed-point combinator</li>
              <li><code>match</code> - Pattern matching</li>
            </ul>

            <h3>STEP 3 - SUBMIT VIA API</h3>
            <p>Use the POST /expressions endpoint to submit your G-Expression to the repository.</p>

            <h3>STEP 4 - ADD VERSIONS</h3>
            <p>Once published, you can add new versions to your G-Expression using semantic versioning.</p>
          </div>
        </div>

        <div class="api-section">
          <h2 id="integration-tutorial">INTEGRATION TUTORIAL</h2>
          <div class="tutorial-content">
            <h3>COMMAND-LINE INTEGRATION</h3>
            <p>Use curl or your preferred HTTP client to interact with the API programmatically.</p>

            <h3>SEARCH AND DISCOVERY</h3>
            <div class="code-sample">
              <code># Search for lambda expressions
              curl "http://localhost:4000/api/v1/expressions?search=lambda"

              # Browse all expressions
              curl "http://localhost:4000/api/v1/expressions"</code>
            </div>

            <h3>AUTOMATED WORKFLOWS</h3>
            <p>Integrate Phoebe into your CI/CD pipeline for automated G-Expression publishing.</p>
          </div>
        </div>

        <div class="api-section">
          <h2 id="validation-tutorial">VALIDATION TUTORIAL</h2>
          <div class="tutorial-content">
            <h3>G-EXPRESSION STRUCTURE</h3>
            <p>Every G-Expression must follow this basic structure with 'g' (type) and 'v' (value) properties.</p>

            <h3>VALIDATION RULES</h3>
            <ul>
              <li>Expression names must be unique and contain only alphanumeric characters, dashes, and underscores</li>
              <li>All G-Expressions must have valid 'g' and 'v' properties</li>
              <li>Lambda expressions require 'params' (array) and 'body' (G-Expression)</li>
              <li>Application expressions require 'fn' and 'args' properties</li>
              <li>Version strings must follow semantic versioning (e.g., "1.0.0")</li>
            </ul>
          </div>
        </div>

        <div class="api-section">
          <h2>RESPONSE FORMAT</h2>
          <p>All API responses follow a consistent JSON structure with 'data' and 'meta' properties.</p>

          <h3>ERROR RESPONSES</h3>
          <p>Errors include detailed messages and validation information when applicable.</p>
        </div>

        <div class="api-section">
          <h2>RATE LIMITS</h2>
          <p>Currently, there are no rate limits imposed on the API. However, please be respectful of the service and avoid excessive requests.</p>
        </div>

        <div class="api-section">
          <h2>SUPPORT</h2>
          <p>For questions about the G-Expression specification, visit the <a href="https://github.com/json-g/json_ge_lib" class="spec-link">JSON G-Expression specification</a>.</p>

          <p>For issues with the Phoebe API or to contribute improvements, please visit our repository or contact the development team.</p>
        </div>
      </div>
    </div>
    """
  end
end