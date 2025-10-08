defmodule Phoebe.Repo.Migrations.CreateVersions do
  use Ecto.Migration

  def change do
    create table(:versions) do
      add :g_expression_id, references(:g_expressions, on_delete: :delete_all), null: false
      add :version, :string, null: false
      add :expression_data, :map, null: false
      add :checksum, :binary

      timestamps()
    end

    create unique_index(:versions, [:g_expression_id, :version])
    create index(:versions, [:g_expression_id])
    create index(:versions, [:inserted_at])
  end
end
