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

    has_many :versions, Version, on_delete: :delete_all

    timestamps()
  end

  @doc false
  def changeset(g_expression, attrs) do
    g_expression
    |> cast(attrs, [:name, :title, :description, :expression_data, :tags])
    |> validate_required([:name, :title, :expression_data])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:title, min: 1, max: 255)
    |> validate_format(:name, ~r/^[a-z][a-z0-9_]*$/, message: "must start with a letter and contain only lowercase letters, numbers, and underscores")
    |> unique_constraint(:name)
    |> validate_expression_data()
  end

  defp validate_expression_data(changeset) do
    case get_field(changeset, :expression_data) do
      nil -> changeset
      data when is_map(data) ->
        case Phoebe.GExpression.Validator.validate(data) do
          {:ok, _} -> changeset
          {:error, message} -> add_error(changeset, :expression_data, message)
        end
      _ -> add_error(changeset, :expression_data, "must be a valid JSON object")
    end
  end
end