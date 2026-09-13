defmodule EAnyPanel.Repo.Migrations.CreateTools do
  use Ecto.Migration

  def change do
    create table(:tools) do
      add :name, :string, null: false
      add :url, :string, null: false
      add :category, :string
      add :source, :string, null: false, default: "internal"
      add :icon_url, :string
      add :is_active, :boolean, null: false, default: true

      timestamps()
    end

    create index(:tools, [:category])
  end
end
