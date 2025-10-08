defmodule Phoebe.Repository do
  @moduledoc """
  The Repository context for managing G-Expressions and their versions.
  """

  import Ecto.Query, warn: false
  alias Phoebe.Repo

  alias Phoebe.Repository.{GExpression, Version}

  @doc """
  Returns the list of g_expressions.
  """
  def list_g_expressions do
    Repo.all(GExpression)
  end

  @doc """
  Gets a single g_expression by name.
  """
  def get_g_expression(name) do
    Repo.get_by(GExpression, name: name)
  end

  @doc """
  Gets a single g_expression by name with versions preloaded.
  """
  def get_g_expression_with_versions(name) do
    from(g in GExpression,
      where: g.name == ^name,
      preload: [versions: ^from(v in Version, order_by: [desc: v.inserted_at])]
    )
    |> Repo.one()
  end

  @doc """
  Creates a g_expression.
  """
  def create_g_expression(attrs \\ %{}) do
    %GExpression{}
    |> GExpression.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a g_expression.
  """
  def update_g_expression(%GExpression{} = g_expression, attrs) do
    g_expression
    |> GExpression.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a g_expression.
  """
  def delete_g_expression(%GExpression{} = g_expression) do
    Repo.delete(g_expression)
  end

  @doc """
  Search g_expressions by name, title, description, or tags.
  """
  def search_g_expressions(query, opts \\ []) when is_binary(query) do
    page = Keyword.get(opts, :page, 1) || 1
    per_page = Keyword.get(opts, :per_page, 20) || 20
    offset = (page - 1) * per_page

    search_term = "%#{query}%"

    from(g in GExpression,
      where:
        ilike(g.name, ^search_term) or
          ilike(g.title, ^search_term) or
          ilike(g.description, ^search_term),
      order_by: [desc: g.downloads_count, desc: g.inserted_at],
      limit: ^per_page,
      offset: ^offset
    )
    |> Repo.all()
  end

  @doc """
  Increment downloads count for a g_expression.
  """
  def increment_downloads(%GExpression{} = g_expression) do
    g_expression
    |> Ecto.Changeset.change(downloads_count: g_expression.downloads_count + 1)
    |> Repo.update()
  end

  # Version functions

  @doc """
  Creates a version for a g_expression.
  """
  def create_version(%GExpression{} = g_expression, attrs \\ %{}) do
    g_expression
    |> Ecto.build_assoc(:versions)
    |> Version.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a specific version of a g_expression.
  """
  def get_version(g_expression_name, version_string) do
    from(v in Version,
      join: g in assoc(v, :g_expression),
      where: g.name == ^g_expression_name and v.version == ^version_string,
      preload: [:g_expression]
    )
    |> Repo.one()
  end

  @doc """
  Lists all versions for a g_expression.
  """
  def list_versions(%GExpression{} = g_expression) do
    from(v in Version,
      where: v.g_expression_id == ^g_expression.id,
      order_by: [desc: v.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Deletes a version.
  """
  def delete_version(%Version{} = version) do
    Repo.delete(version)
  end

  # Dependency functions

  @doc """
  Resolves all dependencies for a G-expression.
  Returns a flat map of package names to resolved versions.
  """
  def resolve_dependencies(package_name) do
    Phoebe.Dependencies.Resolver.resolve(package_name)
  end

  @doc """
  Builds a dependency tree for a G-expression.
  Returns a nested structure showing the full dependency hierarchy.
  """
  def build_dependency_tree(package_name) do
    Phoebe.Dependencies.Resolver.build_tree(package_name)
  end

  @doc """
  Lists all packages that depend on a given G-expression.
  """
  def list_dependents(package_name) do
    from(g in GExpression,
      where: fragment("? @> ?::jsonb", g.dependencies, ^%{package_name => ""}),
      select: %{
        name: g.name,
        title: g.title,
        version_requirement: fragment("?->?", g.dependencies, ^package_name)
      }
    )
    |> Repo.all()
  end
end
