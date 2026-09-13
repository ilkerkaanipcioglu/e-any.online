defmodule EAnyPanelWeb.UserAuth do
  @moduledoc """
  Authentication plug + LiveView on_mount hooks for the e-any admin panel.

  - `fetch_current_user/2` loads the user from the session into `conn.assigns.current_user`.
  - `require_authenticated_user/2` redirects to `/login` when no user is present.
  - `redirect_if_user_is_authenticated/2` bounces already-logged-in users to `/admin`.
  - `on_mount/1` hooks expose `:require_authenticated_user` and
    `:redirect_if_user_is_authenticated` for `live_session` blocks, setting the
    `current_scope` assign required by `<Layouts.app>`.
  """

  import Plug.Conn
  import Phoenix.Controller

  alias EAnyPanel.Accounts
  alias EAnyPanelWeb.Router.Helpers, as: Routes

  @doc """
  Plug that loads the current user from the session.
  """
  def fetch_current_user(conn, _opts) do
    case get_session(conn, :user_id) do
      nil ->
        assign(conn, :current_user, nil)

      user_id ->
        assign(conn, :current_user, Accounts.get_user(user_id))
    end
  end

  @doc """
  Plug that redirects when there is no authenticated user.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: Routes.session_path(conn, :new))
      |> halt()
    end
  end

  @doc """
  Plug that redirects an already authenticated user to the dashboard.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: Routes.dashboard_path(conn, :index))
      |> halt()
    else
      conn
    end
  end

  @doc """
  LiveView on_mount hook used by `live_session` blocks.

  Recognised values:
    - `:require_authenticated_user`  -> halts and redirects to login when no user.
    - `:redirect_if_user_is_authenticated` -> redirects to dashboard when logged in.
  """
  def on_mount(:require_authenticated_user, _params, session, socket) do
    case session do
      %{"user_id" => user_id} ->
        user = Accounts.get_user(user_id)

        if user do
          socket =
            socket
            |> then(fn s -> %{s | assigns: Map.put(s.assigns, :current_user, user)} end)
            |> then(fn s -> %{s | assigns: Map.put(s.assigns, :current_scope, %{user: user})} end)

          {:cont, socket}
        else
          {:halt, redirect(socket, to: Routes.session_path(socket, :new))}
        end

      _ ->
        {:halt, redirect(socket, to: Routes.session_path(socket, :new))}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    case session do
      %{"user_id" => user_id} ->
        user = Accounts.get_user(user_id)

        if user do
          {:halt, redirect(socket, to: Routes.dashboard_path(socket, :index))}
        else
          {:cont, socket}
        end

      _ ->
        {:cont, socket}
    end
  end
end
