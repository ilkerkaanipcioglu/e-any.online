defmodule EAnyPanel.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :hashed_password, :string
    field :totp_secret, :string
    field :role, :string, default: "viewer"
    field :allowed_tabs, :string, default: "[]"

    field :password, :string, virtual: true

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :totp_secret, :role, :allowed_tabs])
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "geçerli bir e-posta girin")
    |> validate_inclusion(:role, ~w(admin manager viewer))
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  defp put_password_hash(%Ecto.Changeset{valid?: true, changes: %{password: pw}} = changeset) do
    put_change(changeset, :hashed_password, Argon2.hash_pwd_salt(pw))
  end

  defp put_password_hash(changeset), do: changeset
end
