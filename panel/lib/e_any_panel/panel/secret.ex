defmodule EAnyPanel.Panel.Secret do
  use Ecto.Schema
  import Ecto.Changeset

  # All sensitive fields are encrypted at rest via Cloak (AES-256-GCM).
  # `is_critical` defaults to true and requires vault re-auth to view.
  schema "secrets" do
    field :title, :string
    field :username, EAnyPanel.Vault.EncryptedString
    field :password, EAnyPanel.Vault.EncryptedString
    field :url, :string
    field :notes, EAnyPanel.Vault.EncryptedString
    field :is_critical, :boolean, default: true

    timestamps()
  end

  def changeset(secret, attrs) do
    secret
    |> cast(attrs, [:title, :username, :password, :url, :notes, :is_critical])
    |> validate_required([:title])
  end
end
