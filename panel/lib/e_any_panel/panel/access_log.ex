defmodule EAnyPanel.Panel.AccessLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "access_logs" do
    field :user_id, :id
    field :secret_id, :id
    field :note_id, :id
    field :ip_address, :string
    field :accessed_at, :utc_datetime

    timestamps()
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:user_id, :secret_id, :note_id, :ip_address, :accessed_at])
    |> validate_required([:user_id, :accessed_at])
  end
end
