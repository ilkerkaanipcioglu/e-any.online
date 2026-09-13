defmodule EAnyPanel.Repo.Migrations.CreateNotes do
  use Ecto.Migration

  def change do
    create table(:notes) do
      add :title, :string, null: false
      add :body, :binary, null: false
      add :is_critical, :boolean, null: false, default: false

      timestamps()
    end
  end
end
