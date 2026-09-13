defmodule EAnyPanelWeb.SessionControllerTest do
  use EAnyPanelWeb.ConnCase, async: true

  import Phoenix.ConnTest

  alias EAnyPanel.Accounts
  alias EAnyPanelWeb.Endpoint

  @create_attrs %{email: "test-auth@e-any.online", password: "SuperSecret123!"}

  setup do
    user = Accounts.create_user!(@create_attrs)
    %{user: user}
  end

  describe "GET /session/create" do
    test "valid token (no TOTP) writes session and redirects to /admin", %{user: user} do
      token = Phoenix.Token.sign(Endpoint, "login", user.id)
      conn = get(build_conn(), ~p"/session/create?token=#{token}")
      assert get_session(conn, :user_id) == user.id
      assert redirected_to(conn) == ~p"/admin"
    end

    test "expired/invalid token redirects to /login" do
      conn = get(build_conn(), ~p"/session/create?token=garbage")
      assert redirected_to(conn) == ~p"/login"
      assert get_flash(conn, :error) =~ "Session expired"
    end

    test "user with TOTP secret cannot skip 2FA (no step param)", %{user: user} do
      {:ok, user} = Accounts.update_user_totp_secret(user, Base.encode32(NimbleTOTP.secret()))
      token = Phoenix.Token.sign(Endpoint, "login", user.id)
      conn = get(build_conn(), ~p"/session/create?token=#{token}")
      # Session must NOT be written
      assert get_session(conn, :user_id) == nil
      # Must be redirected back to the TOTP step
      assert redirected_to(conn) == ~p"/login/totp?token=#{token}"
    end

    test "step=totp redirects to /login/totp without writing session", %{user: user} do
      {:ok, user} = Accounts.update_user_totp_secret(user, Base.encode32(NimbleTOTP.secret()))
      token = Phoenix.Token.sign(Endpoint, "login", user.id)
      conn = get(build_conn(), ~p"/session/create?token=#{token}&step=totp")
      assert get_session(conn, :user_id) == nil
      assert redirected_to(conn) == ~p"/login/totp?token=#{token}"
    end
  end

  describe "DELETE /logout" do
    test "clears the session" do
      user = Accounts.get_user_by_email!("test-auth@e-any.online")
      conn = session_conn() |> put_session(:user_id, user.id) |> delete(~p"/logout")
      assert get_session(conn, :user_id) == nil
      assert redirected_to(conn) == ~p"/login"
    end
  end
end
