defmodule EAnyPanelWeb.DashboardLiveRoleTest do
  use EAnyPanelWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias EAnyPanel.Accounts

  defp create_user(role, tabs) do
    Accounts.create_user!(%{
      email: "roleview_#{System.unique_integer([:positive])}@test.local",
      password: "TestSifre123!",
      role: role,
      allowed_tabs: tabs
    })
  end

  test "viewer with no tabs sees only dashboard menu", %{conn: conn} do
    user = create_user("viewer", "[]")
    conn = log_in_user(conn, user)
    {:ok, view, html} = live(conn, "/admin")
    assert html =~ ~s(href="/admin?tab=dashboard")
    refute html =~ ~s(href="/admin?tab=proxy_hosts")
    refute html =~ ~s(href="/admin?tab=secrets")
    refute html =~ ~s(href="/admin?tab=users")
    refute html =~ ~s(href="/admin?tab=activity")
  end

  test "viewer with activity tab sees Sap menu", %{conn: conn} do
    user = create_user("viewer", ~s(["activity"]))
    conn = log_in_user(conn, user)
    {:ok, view, html} = live(conn, "/admin")
    assert html =~ ~s(href="/admin?tab=activity")
    refute html =~ ~s(href="/admin?tab=proxy_hosts")
    refute html =~ ~s(href="/admin?tab=secrets")
  end

  test "manager sees allowed tabs", %{conn: conn} do
    user = create_user("manager", ~s(["activity","proxy_hosts"]))
    conn = log_in_user(conn, user)
    {:ok, view, html} = live(conn, "/admin")
    assert html =~ ~s(href="/admin?tab=activity")
    assert html =~ ~s(href="/admin?tab=proxy_hosts")
    assert html =~ ~s(href="/admin?tab=dashboard")
    refute html =~ ~s(href="/admin?tab=secrets")
    refute html =~ ~s(href="/admin?tab=users")
  end

  test "admin sees everything", %{conn: conn} do
    user = create_user("admin", "[]")
    conn = log_in_user(conn, user)
    {:ok, view, html} = live(conn, "/admin")
    assert html =~ ~s(href="/admin?tab=proxy_hosts")
    assert html =~ ~s(href="/admin?tab=secrets")
    assert html =~ ~s(href="/admin?tab=users")
    assert html =~ ~s(href="/admin?tab=activity")
    assert html =~ ~s(href="/admin?tab=settings")
    assert html =~ ~s(href="/admin?tab=landing")
  end

  defp log_in_user(conn, user) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end
end