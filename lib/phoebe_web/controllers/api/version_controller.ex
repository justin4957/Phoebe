defmodule PhoebeWeb.API.VersionController do
  use PhoebeWeb, :controller

  alias Phoebe.Repository

  action_fallback PhoebeWeb.FallbackController

  def index(conn, %{"name" => name}) do
    case Repository.get_g_expression(name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "G-Expression not found"})

      g_expression ->
        versions = Repository.list_versions(g_expression)
        render(conn, :index, versions: versions)
    end
  end

  def create(conn, %{"name" => name, "version" => version_params}) do
    case Repository.get_g_expression(name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "G-Expression not found"})

      g_expression ->
        with {:ok, version} <- Repository.create_version(g_expression, version_params) do
          conn
          |> put_status(:created)
          |> put_resp_header(
            "location",
            ~p"/api/v1/expressions/#{name}/versions/#{version.version}"
          )
          |> render(:show, version: version)
        end
    end
  end

  def show(conn, %{"name" => name, "version" => version_string}) do
    case Repository.get_version(name, version_string) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Version not found"})

      version ->
        render(conn, :show, version: version)
    end
  end

  def delete(conn, %{"name" => name, "version" => version_string}) do
    case Repository.get_version(name, version_string) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Version not found"})

      version ->
        with {:ok, _} <- Repository.delete_version(version) do
          send_resp(conn, :no_content, "")
        end
    end
  end
end
