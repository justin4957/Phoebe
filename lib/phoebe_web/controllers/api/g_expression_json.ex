defmodule PhoebeWeb.API.GExpressionJSON do

  @doc """
  Renders a list of g_expressions.
  """
  def index(%{g_expressions: g_expressions}) do
    %{
      data: for(g_expression <- g_expressions, do: data(g_expression)),
      meta: %{
        total: length(g_expressions)
      }
    }
  end

  @doc """
  Renders a single g_expression.
  """
  def show(%{g_expression: g_expression}) do
    %{data: data(g_expression)}
  end

  defp data(g_expression) do
    %{
      id: g_expression.id,
      name: g_expression.name,
      title: g_expression.title,
      description: g_expression.description,
      expression_data: g_expression.expression_data,
      tags: g_expression.tags,
      downloads_count: g_expression.downloads_count,
      inserted_at: g_expression.inserted_at,
      updated_at: g_expression.updated_at,
      versions: render_versions(g_expression.versions)
    }
  end

  defp render_versions(versions) when is_list(versions) do
    for version <- versions do
      %{
        version: version.version,
        inserted_at: version.inserted_at,
        checksum: if(version.checksum, do: Base.encode16(version.checksum, case: :lower))
      }
    end
  end
  defp render_versions(_), do: []
end