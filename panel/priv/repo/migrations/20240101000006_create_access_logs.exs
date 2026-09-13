defmodule EAnyPanel.Repo.Migrations.CreateAccessLogs do
  use Ecto.Migration

  def change do
    create table(:access_logs) do
      add :user_id, references(:users, on_delete: :nothing)
      add :secret_id, references(:secrets, on_delete: :nothing)
      add :note_id, references(:notes, on_delete: :nothing)
      add :ip_address, :string
      add :accessed_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:access_logs, [:user_id])
    create index(:access_logs, [:accessed_at])
  end
end
