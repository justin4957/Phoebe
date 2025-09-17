defmodule Phoebe.Repo.Migrations.CreateGExpressions do
  use Ecto.Migration

  def change do
    create table(:g_expressions) do
      add :name, :string, null: false
      add :title, :string, null: false
      add :description, :text
      add :expression_data, :map, null: false
      add :tags, {:array, :string}, default: []
      add :downloads_count, :integer, default: 0

      timestamps()
    end

    create unique_index(:g_expressions, [:name])
    create index(:g_expressions, [:tags])
    create index(:g_expressions, [:downloads_count])
    create index(:g_expressions, [:inserted_at])
  end
end