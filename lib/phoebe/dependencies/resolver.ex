defmodule Phoebe.Dependencies.Resolver do
  @moduledoc """
  Simple, functional dependency resolver for G-expressions.

  Keeps resolution minimal and composable, following lambda calculus principles:
  - Pure functions for resolution
  - Immutable dependency graphs
  - Simple recursive resolution
  """

  alias Phoebe.Repository

  @doc """
  Resolves dependencies for a given G-expression, returning a flat dependency map.

  Returns `{:ok, resolved_deps}` where resolved_deps is a map of package names to versions,
  or `{:error, reason}` if resolution fails.

  ## Examples

      iex> resolve("my_package")
      {:ok, %{"identity" => "1.0.0", "logical_and" => "1.2.0"}}
  """
  def resolve(package_name) when is_binary(package_name) do
    case Repository.get_g_expression_with_versions(package_name) do
      nil -> {:error, "Package not found: #{package_name}"}
      g_expression -> resolve_dependencies(g_expression, %{}, [])
    end
  end

  @doc """
  Resolves dependencies from a dependencies map (without loading from DB).
  Useful for validating dependency specifications.
  """
  def resolve_map(dependencies) when is_map(dependencies) do
    resolve_dependencies_map(dependencies, %{}, [])
  end

  @doc """
  Builds a dependency tree showing the full hierarchy.
  Returns nested structure showing which packages depend on which.
  """
  def build_tree(package_name) when is_binary(package_name) do
    case Repository.get_g_expression_with_versions(package_name) do
      nil -> {:error, "Package not found: #{package_name}"}
      g_expression -> build_dependency_tree(g_expression, [])
    end
  end

  # Private functions

  defp resolve_dependencies(g_expression, resolved, path) do
    package_name = g_expression.name
    dependencies = g_expression.dependencies || %{}

    # Check for circular dependencies
    if package_name in path do
      {:error, "Circular dependency detected: #{format_cycle(path, package_name)}"}
    else
      # Get the latest version for this package
      latest_version = get_latest_version(g_expression)

      # Add to resolved map
      resolved = Map.put(resolved, package_name, latest_version)

      # Recursively resolve each dependency
      resolve_dependencies_map(dependencies, resolved, [package_name | path])
    end
  end

  defp resolve_dependencies_map(dependencies, resolved, path) do
    Enum.reduce_while(dependencies, {:ok, resolved}, fn {dep_name, version_req}, {:ok, acc} ->
      # Skip if already resolved
      if Map.has_key?(acc, dep_name) do
        # Check version compatibility
        case check_version_compatibility(acc[dep_name], version_req) do
          :ok -> {:cont, {:ok, acc}}
          {:error, _} = error -> {:halt, error}
        end
      else
        # Resolve this dependency
        case Repository.get_g_expression_with_versions(dep_name) do
          nil ->
            {:halt, {:error, "Dependency not found: #{dep_name}"}}

          dep_expr ->
            # Find a version that satisfies the requirement
            case find_matching_version(dep_expr, version_req) do
              {:ok, version} ->
                # Recursively resolve this dependency's dependencies
                case resolve_dependencies(dep_expr, Map.put(acc, dep_name, version), path) do
                  {:ok, new_resolved} -> {:cont, {:ok, new_resolved}}
                  {:error, _} = error -> {:halt, error}
                end

              {:error, _} = error ->
                {:halt, error}
            end
        end
      end
    end)
  end

  defp build_dependency_tree(g_expression, path) do
    package_name = g_expression.name
    dependencies = g_expression.dependencies || %{}

    if package_name in path do
      {:error, "Circular dependency detected: #{format_cycle(path, package_name)}"}
    else
      children =
        Enum.map(dependencies, fn {dep_name, version_req} ->
          case Repository.get_g_expression_with_versions(dep_name) do
            nil ->
              %{name: dep_name, version_req: version_req, error: "not found"}

            dep_expr ->
              case build_dependency_tree(dep_expr, [package_name | path]) do
                {:ok, tree} -> tree
                {:error, reason} -> %{name: dep_name, error: reason}
              end
          end
        end)

      {:ok,
       %{
         name: package_name,
         version: get_latest_version(g_expression),
         dependencies: children
       }}
    end
  end

  defp get_latest_version(g_expression) do
    case g_expression.versions do
      [] ->
        "0.0.0"

      versions ->
        versions
        |> Enum.map(& &1.version)
        |> Enum.sort({:desc, Version})
        |> List.first()
    end
  end

  defp find_matching_version(g_expression, version_req) do
    versions = g_expression.versions || []

    matching_version =
      versions
      |> Enum.map(& &1.version)
      |> Enum.filter(&matches_requirement?(&1, version_req))
      |> Enum.sort({:desc, Version})
      |> List.first()

    case matching_version do
      nil -> {:error, "No version of #{g_expression.name} matches requirement: #{version_req}"}
      version -> {:ok, version}
    end
  end

  defp matches_requirement?(version, requirement) do
    # Parse requirement operator
    case parse_requirement(requirement) do
      {:ok, operator, req_version} ->
        compare_versions(version, operator, req_version)

      :error ->
        false
    end
  end

  defp parse_requirement(requirement) do
    cond do
      String.starts_with?(requirement, "~>") ->
        version = String.trim_leading(requirement, "~>") |> String.trim()
        {:ok, :compatible, version}

      String.starts_with?(requirement, ">=") ->
        version = String.trim_leading(requirement, ">=") |> String.trim()
        {:ok, :gte, version}

      String.starts_with?(requirement, ">") ->
        version = String.trim_leading(requirement, ">") |> String.trim()
        {:ok, :gt, version}

      String.starts_with?(requirement, "<=") ->
        version = String.trim_leading(requirement, "<=") |> String.trim()
        {:ok, :lte, version}

      String.starts_with?(requirement, "<") ->
        version = String.trim_leading(requirement, "<") |> String.trim()
        {:ok, :lt, version}

      String.starts_with?(requirement, "==") ->
        version = String.trim_leading(requirement, "==") |> String.trim()
        {:ok, :eq, version}

      String.match?(requirement, ~r/^\d+\.\d+\.\d+/) ->
        {:ok, :eq, String.trim(requirement)}

      true ->
        :error
    end
  end

  defp compare_versions(version, operator, required_version) do
    case Version.compare(version, required_version) do
      :gt ->
        operator in [:gt, :gte, :compatible] and compatible?(version, required_version, operator)

      :eq ->
        operator in [:eq, :gte, :lte, :compatible]

      :lt ->
        operator in [:lt, :lte]
    end
  end

  defp compatible?(version, required_version, :compatible) do
    # ~> 1.2.3 means >= 1.2.3 and < 1.3.0
    # ~> 1.2 means >= 1.2.0 and < 2.0.0
    with {:ok, v} <- Version.parse(version),
         {:ok, req} <- Version.parse(required_version) do
      cond do
        req.patch == 0 and req.minor == 0 ->
          # ~> 1.0 means >= 1.0.0 and < 2.0.0
          v.major == req.major

        req.patch == 0 ->
          # ~> 1.2 means >= 1.2.0 and < 1.3.0
          v.major == req.major and v.minor == req.minor

        true ->
          # ~> 1.2.3 means >= 1.2.3 and < 1.3.0
          v.major == req.major and v.minor == req.minor and v.patch >= req.patch
      end
    else
      _ -> false
    end
  end

  defp compatible?(_version, _required_version, _operator), do: true

  defp check_version_compatibility(existing_version, new_requirement) do
    if matches_requirement?(existing_version, new_requirement) do
      :ok
    else
      {:error,
       "Version conflict: #{existing_version} doesn't match requirement #{new_requirement}"}
    end
  end

  defp format_cycle(path, current) do
    cycle = Enum.reverse([current | path])
    Enum.join(cycle, " -> ")
  end
end
