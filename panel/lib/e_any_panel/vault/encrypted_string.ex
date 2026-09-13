defmodule EAnyPanel.Vault.EncryptedString do
  use Cloak.Ecto.Binary, vault: EAnyPanel.Vault
end
