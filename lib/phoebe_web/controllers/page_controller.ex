defmodule PhoebeWeb.PageController do
  use PhoebeWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
