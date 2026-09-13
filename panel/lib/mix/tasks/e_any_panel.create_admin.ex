defmodule Mix.Tasks.EAnyPanel.CreateAdmin do
  @moduledoc """
  Creates an admin user with the given email and password.
  A TOTP secret is automatically generated.

  Usage:
      mix e_any_panel.create_admin EMAIL PASSWORD
  """
  use Mix.Task
  alias EAnyPanel.Accounts

  @shortdoc "Creates an admin user"

  @impl Mix.Task
  def run([email, password]) do
    # Start the application and repo to ensure DB access
    Mix.Task.run("app.start")

    totp_secret = NimbleTOTP.secret()

    case Accounts.create_user(%{
           email: email,
           password: password,
           totp_secret: Base.encode32(totp_secret)
         }) do
      {:ok, user} ->
        Mix.shell().info("Admin created: #{user.email}")

      {:error, changeset} ->
        Mix.shell().error("Failed to create admin:")

        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
              opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
            end)
          end)

        Enum.each(errors, fn {field, msgs} ->
          Enum.each(msgs, fn msg ->
            Mix.shell().error("  #{field}: #{msg}")
          end)
        end)

        exit({:shutdown, 1})
    end
  end

  def run(_) do
    Mix.shell().error("Usage: mix e_any_panel.create_admin EMAIL PASSWORD")
    exit({:shutdown, 1})
  end
end
