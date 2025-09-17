defmodule PhoebeWeb.Router do
  use PhoebeWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PhoebeWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PhoebeWeb do
    pipe_through :browser

    live "/", HomeLive, :index
    live "/expressions", ExpressionLive.Index, :index
    live "/expressions/:name", ExpressionLive.Show, :show
    live "/api/v1", ApiDocsLive, :index
  end

  # API Routes
  scope "/api/v1", PhoebeWeb.API, as: :api do
    pipe_through :api

    # G-Expression routes
    get "/expressions", GExpressionController, :index
    post "/expressions", GExpressionController, :create
    get "/expressions/:name", GExpressionController, :show
    put "/expressions/:name", GExpressionController, :update
    delete "/expressions/:name", GExpressionController, :delete

    # Version routes
    get "/expressions/:name/versions", VersionController, :index
    post "/expressions/:name/versions", VersionController, :create
    get "/expressions/:name/versions/:version", VersionController, :show
    delete "/expressions/:name/versions/:version", VersionController, :delete
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:phoebe, :dev_routes) do

    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
