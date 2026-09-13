defmodule EAnyPanelWeb.PageController do
  use EAnyPanelWeb, :controller

  alias EAnyPanel.Accounts

  def home(conn, _params) do
    case get_session(conn, :user_id) do
      nil ->
        render(conn, :home)

      user_id ->
        if Accounts.get_user(user_id) do
          redirect(conn, to: ~p"/admin")
        else
          conn |> clear_session() |> render(:home)
        end
    end
  end
end
