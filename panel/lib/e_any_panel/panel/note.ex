defmodule EAnyPanel.Panel.Note do
  use Ecto.Schema
  import Ecto.Changeset

  # `body` is always stored encrypted (Cloak). `is_critical` drives the
  # vault re-authentication gate in the UI: critical notes are locked behind a
  # password prompt and only rendered after re-auth.
  schema "notes" do
    field :title, :string
    field :body, EAnyPanel.Vault.EncryptedString
    field :is_critical, :boolean, default: false

    timestamps()
  end

  def changeset(note, attrs) do
    note
    |> cast(attrs, [:title, :body, :is_critical])
    |> validate_required([:title, :body])
  end
end
