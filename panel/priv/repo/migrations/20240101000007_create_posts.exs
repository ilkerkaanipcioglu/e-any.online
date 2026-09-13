defmodule EAnyPanel.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :title, :string, null: false
      add :slug, :string, null: false
      add :type, :string, null: false, default: "blog"
      add :body, :text
      add :excerpt, :string
      add :author, :string, default: "E-Any"
      add :sites, {:array, :string}, default: []
      add :canonical_site, :string
      add :tags, {:array, :string}, default: []
      add :source_url, :string
      add :source_name, :string
      add :published, :boolean, default: true
      add :published_at, :utc_datetime

      timestamps()
    end

    create unique_index(:posts, [:slug])
    create index(:posts, [:published_at])
    create index(:posts, [:type])
  end
end
