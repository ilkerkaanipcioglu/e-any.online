defmodule EAnyPanel.Repo do
  use Ecto.Repo,
    otp_app: :e_any_panel,
    adapter: Ecto.Adapters.Postgres
end
