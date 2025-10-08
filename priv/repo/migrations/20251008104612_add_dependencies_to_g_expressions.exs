defmodule Phoebe.Repo.Migrations.AddDependenciesToGExpressions do
  use Ecto.Migration

  def change do
    alter table(:g_expressions) do
      add :dependencies, :map, default: %{}
    end
  end
end
