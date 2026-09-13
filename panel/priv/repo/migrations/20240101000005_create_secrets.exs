defmodule EAnyPanel.Repo.Migrations.CreateSecrets do
  use Ecto.Migration

  def change do
    create table(:secrets) do
      add :title, :string, null: false
      add :username, :binary
      add :password, :binary
      add :url, :string
      add :notes, :binary
      add :is_critical, :boolean, null: false, default: true

      timestamps()
    end
  end
end
