defmodule EAnyPanel.Repo.Migrations.AddRoleAndAllowedTabsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :role, :string, default: "viewer", null: false
      add :allowed_tabs, :text, default: "[]"
    end

    create index(:users, [:role])
  end
end