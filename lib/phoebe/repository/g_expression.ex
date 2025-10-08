defmodule Phoebe.Repository.GExpression do
  @moduledoc """
  Schema for G-Expression packages.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Phoebe.Repository.Version

  @derive {Phoenix.Param, key: :name}

  schema "g_expressions" do
    field :name, :string
    field :title, :string
    field :description, :string
    field :expression_data, :map
    field :tags, {:array, :string}, default: []
    field :downloads_count, :integer, default: 0
    field :dependencies, :map, default: %{}

    has_many :versions, Version, on_delete: :delete_all

    timestamps()
  end

  @doc false
  def changeset(g_expression, attrs) do
    g_expression
    |> cast(attrs, [:name, :title, :description, :expression_data, :tags, :dependencies])
    |> validate_required([:name, :title, :expression_data])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:title, min: 1, max: 255)
    |> validate_format(:name, ~r/^[a-z][a-z0-9_]*$/,
      message:
        "must start with a letter and contain only lowercase letters, numbers, and underscores"
    )
    |> unique_constraint(:name)
    |> validate_expression_data()
    |> validate_dependencies()
  end

  defp validate_expression_data(changeset) do
    case get_field(changeset, :expression_data) do
      nil ->
        changeset

      data when is_map(data) ->
        case Phoebe.GExpression.Validator.validate(data) do
          {:ok, _} -> changeset
          {:error, message} -> add_error(changeset, :expression_data, message)
        end

      _ ->
        add_error(changeset, :expression_data, "must be a valid JSON object")
    end
  end

  defp validate_dependencies(changeset) do
    case get_field(changeset, :dependencies) do
      nil ->
        changeset

      deps when is_map(deps) ->
        validate_dependency_map(changeset, deps)

      _ ->
        add_error(
          changeset,
          :dependencies,
          "must be a map of package names to version requirements"
        )
    end
  end

  defp validate_dependency_map(changeset, deps) do
    Enum.reduce(deps, changeset, fn {name, version_req}, acc ->
      cond do
        not is_binary(name) ->
          add_error(acc, :dependencies, "dependency names must be strings")

        not is_binary(version_req) ->
          add_error(acc, :dependencies, "version requirements must be strings")

        not valid_package_name?(name) ->
          add_error(acc, :dependencies, "invalid dependency name: #{name}")

        not valid_version_requirement?(version_req) ->
          add_error(acc, :dependencies, "invalid version requirement for #{name}: #{version_req}")

        true ->
          acc
      end
    end)
  end

  defp valid_package_name?(name) do
    String.match?(name, ~r/^[a-z][a-z0-9_]*$/)
  end

  defp valid_version_requirement?(req) do
    # Basic semver validation - supports ~>, >=, >, <, <=, ==, and plain versions
    String.match?(req, ~r/^(~>|>=|>|<|<=|==)?\s*\d+\.\d+\.\d+/)
  end
end
