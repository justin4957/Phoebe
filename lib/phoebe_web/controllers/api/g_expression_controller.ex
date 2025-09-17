defmodule PhoebeWeb.API.GExpressionController do
  use PhoebeWeb, :controller

  alias Phoebe.Repository

  action_fallback PhoebeWeb.FallbackController

  def index(conn, params) do
    g_expressions = case params["search"] do
      search when is_binary(search) and search != "" ->
        Repository.search_g_expressions(search, page: safe_int(params["page"]), per_page: safe_int(params["per_page"]))
      _ ->
        Repository.list_g_expressions()
    end

    render(conn, :index, g_expressions: g_expressions)
  end

  def create(conn, %{"g_expression" => g_expression_params}) do
    with {:ok, g_expression} <- Repository.create_g_expression(g_expression_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/v1/expressions/#{g_expression}")
      |> render(:show, g_expression: g_expression)
    end
  end

  def show(conn, %{"name" => name}) do
    case Repository.get_g_expression_with_versions(name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "G-Expression not found"})
      g_expression ->
        # Increment download counter
        Repository.increment_downloads(g_expression)
        render(conn, :show, g_expression: g_expression)
    end
  end

  def update(conn, %{"name" => name, "g_expression" => g_expression_params}) do
    g_expression = Repository.get_g_expression(name)

    with {:ok, g_expression} <- Repository.update_g_expression(g_expression, g_expression_params) do
      render(conn, :show, g_expression: g_expression)
    end
  end

  def delete(conn, %{"name" => name}) do
    g_expression = Repository.get_g_expression(name)

    with {:ok, _} <- Repository.delete_g_expression(g_expression) do
      send_resp(conn, :no_content, "")
    end
  end

  defp safe_int(nil), do: nil
  defp safe_int(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, _} when int > 0 -> int
      _ -> nil
    end
  end
  defp safe_int(int) when is_integer(int), do: int
end