defmodule EAnyPanelWeb.SessionController do
  use EAnyPanelWeb, :controller

  alias EAnyPanel.Accounts

  @doc """
  Receives the signed login token produced by `SessionLive` after a successful
  password check.

  Two-step flow:
    - `GET /session/create?token=X&step=totp` -> password was valid, TOTP still
      pending. We DO NOT write the session yet; instead we render the TOTP
      LiveView so the user can complete 2FA.
    - `GET /session/create?token=X` (no step) -> TOTP already verified (or the
      user has no TOTP secret). We write `user_id` into the Plug session and
      redirect to the dashboard.

  Websockets cannot mutate the Plug session, so this controller is the single
  place where the auth cookie is set.
  """
  def create(conn, %{"token" => token} = params) do
    case Phoenix.Token.verify(EAnyPanelWeb.Endpoint, "login", token, max_age: 120) do
      {:ok, user_id} ->
        user = Accounts.get_user(user_id)

        cond do
          # TOTP pending: hand off to the second-factor LiveView without writing
          # the session yet (so 2FA cannot be skipped).
          params["step"] == "totp" ->
            conn
            |> redirect(to: ~p"/login/totp?token=#{token}")

          # User has no TOTP secret configured: single-factor is enough.
          is_nil(user) or is_nil(user.totp_secret) ->
            conn
            |> put_session(:user_id, user_id)
            |> redirect(to: ~p"/admin")

          # SECURITY: user HAS a TOTP secret but no step param means 2FA was
          # skipped. Reject and force the second factor.
          true ->
            conn
            |> put_flash(:error, "Two-factor authentication required.")
            |> redirect(to: ~p"/login/totp?token=#{token}")
        end

      {:error, _} ->
        conn
        |> put_flash(:error, "Session expired, please log in again.")
        |> redirect(to: ~p"/login")
    end
  end

  @doc """
  Clears the session and redirects to login.
  """
  def delete(conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: ~p"/login")
  end
end
