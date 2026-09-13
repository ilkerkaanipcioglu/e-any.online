defmodule EAnyPanel.Vault do
  @moduledoc """
  Cloak vault for field-level encryption (AES-256-GCM).

  The 32-byte key is loaded from the CLOAK_KEY environment variable
  (base64-encoded) and configured in config/runtime.exs. The key is never
  written to disk in the repo and is provided as a Docker secret / env var.
  """
  use Cloak.Vault, otp_app: :e_any_panel
end
