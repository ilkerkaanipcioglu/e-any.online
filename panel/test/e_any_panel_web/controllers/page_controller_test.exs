defmodule EAnyPanelWeb.PageControllerTest do
  use EAnyPanelWeb.ConnCase

  test "GET / renders the panel entry page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "e-any.online"
    assert html_response(conn, 200) =~ "Panele Giriş Yap"
  end

  test "GET / with logged-in user redirects to /admin", %{conn: conn} do
    user =
      EAnyPanel.Accounts.create_user!(%{
        email: "landing@e-any.online",
        password: "SuperSecret123!"
      })

    conn = Plug.Test.init_test_session(conn, %{user_id: user.id})
    conn = get(conn, "/")
    assert redirected_to(conn) == "/admin"
  end
end
