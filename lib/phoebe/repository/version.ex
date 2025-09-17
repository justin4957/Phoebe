defmodule Phoebe.Repository.Version do
  @moduledoc """
  Schema for G-Expression versions.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Phoebe.Repository.GExpression

  schema "versions" do
    field :version, :string
    field :expression_data, :map
    field :checksum, :binary

    belongs_to :g_expression, GExpression

    timestamps()
  end

  @doc false
  def changeset(version, attrs) do
    version
    |> cast(attrs, [:version, :expression_data])
    |> validate_required([:version, :expression_data])
    |> validate_format(:version, ~r/^\d+\.\d+\.\d+(-[a-zA-Z0-9\-\.]+)?(\+[a-zA-Z0-9\-\.]+)?$/,
         message: "must be a valid semantic version (e.g., 1.0.0, 1.0.0-alpha, 1.0.0+build)")
    |> unique_constraint([:g_expression_id, :version])
    |> validate_expression_data()
    |> put_checksum()
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

  defp put_checksum(changeset) do
    case get_field(changeset, :expression_data) do
      nil -> changeset
      data ->
        json_string = Jason.encode!(data, sort_keys: true)
        checksum = :crypto.hash(:sha256, json_string)
        put_change(changeset, :checksum, checksum)
    end
  end
end