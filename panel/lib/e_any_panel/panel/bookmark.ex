defmodule EAnyPanel.Panel.Bookmark do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bookmarks" do
    field :title, :string
    field :url, :string
    field :category, :string
    field :note, :string

    timestamps()
  end

  def changeset(bookmark, attrs) do
    bookmark
    |> cast(attrs, [:title, :url, :category, :note])
    |> validate_required([:title, :url])
  end
end
