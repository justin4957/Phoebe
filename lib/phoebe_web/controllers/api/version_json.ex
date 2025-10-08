defmodule PhoebeWeb.API.VersionJSON do
  @doc """
  Renders a list of versions.
  """
  def index(%{versions: versions}) do
    %{
      data: for(version <- versions, do: data(version)),
      meta: %{
        total: length(versions)
      }
    }
  end

  @doc """
  Renders a single version.
  """
  def show(%{version: version}) do
    %{data: data(version)}
  end

  defp data(version) do
    %{
      id: version.id,
      version: version.version,
      expression_data: version.expression_data,
      checksum: if(version.checksum, do: Base.encode16(version.checksum, case: :lower)),
      g_expression_name: get_expression_name(version),
      inserted_at: version.inserted_at,
      updated_at: version.updated_at
    }
  end

  defp get_expression_name(%{g_expression: %{name: name}}), do: name
  defp get_expression_name(_), do: nil
end
