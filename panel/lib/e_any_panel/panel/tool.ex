defmodule EAnyPanel.Panel.Tool do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tools" do
    field :name, :string
    field :url, :string
    field :category, :string
    field :source, :string, default: "internal"
    field :icon_url, :string
    field :is_active, :boolean, default: true

    timestamps()
  end

  def changeset(tool, attrs) do
    tool
    |> cast(attrs, [:name, :url, :category, :source, :icon_url, :is_active])
    |> validate_required([:name, :url, :source])
    |> validate_inclusion(:source, ["internal", "external"])
  end
end
