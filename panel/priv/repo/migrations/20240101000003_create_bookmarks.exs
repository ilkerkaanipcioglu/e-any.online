defmodule EAnyPanel.Repo.Migrations.CreateBookmarks do
  use Ecto.Migration

  def change do
    create table(:bookmarks) do
      add :title, :string, null: false
      add :url, :string, null: false
      add :category, :string
      add :note, :text

      timestamps()
    end
  end
end
