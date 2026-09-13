defmodule EAnyPanel.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :hashed_password, :string, null: false
      add :totp_secret, :string

      timestamps()
    end

    create unique_index(:users, [:email])
  end
end
