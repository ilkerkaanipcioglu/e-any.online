defmodule EAnyPanelWeb.DashboardLive do
  use EAnyPanelWeb, :live_view

  alias EAnyPanel.Accounts
  alias EAnyPanel.Panel
  alias EAnyPanel.NpmClient

  @tabs [
    dashboard: "Dashboard",
    landing: "Landing",
    proxy_hosts: "Proxy Hosts",
    access_lists: "Access Lists",
    certificates: "Certificates",
    users: "Users",
    notes: "Notlar",
    tools: "Araçlar",
    bookmarks: "Bookmarks",
    secrets: "Secrets",
    audit_logs: "Audit Logs",
    activity: "Sap",
    settings: "Settings"
  ]

  # Rol bazlı menü görünürlüğü — admin her şeyi görür; manager/viewer
  # sadece kendilerine atanan sekmeleri görür (Accounts.allowed_tabs_for).
  @default_viewer_tabs [:dashboard]

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    visible_tabs = visible_tabs_for(user)

    socket =
      socket
      |> assign(:current_scope, %{user: user})
      |> assign(:tab, :dashboard)
      |> assign(:tabs, @tabs)
      |> assign(:visible_tabs, visible_tabs)
      |> assign(:sidebar_open, false)
      |> assign(:editing_perms_user, nil)
      |> assign(:modal, nil)
      |> assign(:editing, nil)
      |> assign(:revealed_secrets, MapSet.new())
      |> assign(:bookmark_form, to_form(%{}))
      |> assign(:secret_form, to_form(%{}))
      |> assign(:note_form, to_form(%{}))
      |> assign(:tool_form, to_form(%{}))
      |> assign(:search_term, "")
      |> assign(:search_results, nil)
      |> assign(:npm_proxy_hosts, [])
      |> assign(:npm_access_lists, [])
      |> assign(:npm_certificates, [])
      |> assign(:npm_users, [])
      |> assign(:npm_audit_logs, [])
      |> assign(:npm_loaded, false)
      |> assign(:app_users, Accounts.list_users() || [])
      |> assign(:tools, Panel.list_tools() || [])
      |> assign(:bookmarks, Panel.list_bookmarks() || [])
      |> assign(:notes, Panel.list_notes() || [])
      |> assign(:secrets, Panel.list_secrets() || [])
      |> assign(:access_logs, Panel.recent_access(nil, 20) || [])
      |> assign(:vault_locked, true)
      |> assign(:vault_unlock_modal, false)
      |> assign(:vault_password, to_form(%{}))

    {:ok, socket}
  end

  def handle_params(%{"tab" => tab}, _uri, socket) do
    tab = String.to_existing_atom(tab)

    if tab in socket.assigns.visible_tabs do
      {:noreply, socket |> assign(:tab, tab) |> maybe_load_npm(tab)}
    else
      # Yetkisiz sekme -> dashboard'a geri at
      {:noreply,
       socket
       |> put_flash(:error, "Bu sekmeye erişim yetkiniz yok.")
       |> push_patch(to: ~p"/admin?tab=dashboard")}
    end
  rescue
    _ -> {:noreply, assign(socket, :tab, :dashboard)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  # NPM verilerini sadece NPM sekmelerine girilince yükle (mount'u hızlı tut).
  defp maybe_load_npm(socket, tab)
       when tab in [:proxy_hosts, :access_lists, :certificates, :activity] do
    if socket.assigns.npm_loaded do
      socket
    else
      socket
      |> assign(:npm_proxy_hosts, NpmClient.list_proxy_hosts() || [])
      |> assign(:npm_access_lists, NpmClient.list_access_lists() || [])
      |> assign(:npm_certificates, NpmClient.list_certificates() || [])
      |> assign(:npm_users, NpmClient.list_users() || [])
      |> assign(:npm_audit_logs, NpmClient.list_audit_logs() || [])
      |> assign(:npm_loaded, true)
    end
  end

  defp maybe_load_npm(socket, _tab), do: socket

  def handle_event("nav", %{"tab" => tab}, socket) do
    tab_atom = String.to_existing_atom(tab)

    if tab_atom in socket.assigns.visible_tabs do
      {:noreply, push_patch(socket, to: ~p"/admin?tab=#{tab}")}
    else
      {:noreply, put_flash(socket, :error, "Bu sekmeye erişim yetkiniz yok.")}
    end
  rescue
    _ -> {:noreply, socket}
  end

  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_open, not socket.assigns.sidebar_open)}
  end

  def handle_event("refresh", _params, socket) do
    {:noreply,
     socket
     |> assign(:npm_proxy_hosts, NpmClient.list_proxy_hosts())
     |> assign(:npm_access_lists, NpmClient.list_access_lists())
     |> assign(:npm_certificates, NpmClient.list_certificates())
     |> assign(:npm_users, NpmClient.list_users())
     |> assign(:npm_audit_logs, NpmClient.list_audit_logs())}
  end

  # --- Search ---------------------------------------------------------------
  def handle_event("search", %{"q" => term}, socket) do
    results = if String.trim(term) == "", do: nil, else: Panel.search(term)
    {:noreply, assign(socket, search_term: term, search_results: results)}
  end

  # --- Modal control ------------------------------------------------------
  def handle_event("open_bookmark_modal", _params, socket) do
    {:noreply,
     assign(socket,
       modal: :bookmark,
       editing: nil,
       bookmark_form: to_form(Panel.Bookmark.changeset(%Panel.Bookmark{}, %{}))
     )}
  end

  def handle_event("open_bookmark_modal", %{"id" => id}, socket) do
    bm = Panel.get_bookmark(id)

    {:noreply,
     assign(socket,
       modal: :bookmark,
       editing: bm,
       bookmark_form: to_form(Panel.Bookmark.changeset(bm, %{}))
     )}
  end

  def handle_event("open_secret_modal", _params, socket) do
    {:noreply,
     assign(socket,
       modal: :secret,
       editing: nil,
       secret_form: to_form(Panel.Secret.changeset(%Panel.Secret{}, %{}))
     )}
  end

  def handle_event("open_secret_modal", %{"id" => id}, socket) do
    s = Panel.get_secret(id)

    {:noreply,
     assign(socket,
       modal: :secret,
       editing: s,
       secret_form: to_form(Panel.Secret.changeset(s, %{}))
     )}
  end

  def handle_event("open_note_modal", _params, socket) do
    {:noreply,
     assign(socket,
       modal: :note,
       editing: nil,
       note_form: to_form(Panel.Note.changeset(%Panel.Note{}, %{}))
     )}
  end

  def handle_event("open_note_modal", %{"id" => id}, socket) do
    n = Panel.get_note(id)

    {:noreply,
     assign(socket, modal: :note, editing: n, note_form: to_form(Panel.Note.changeset(n, %{})))}
  end

  def handle_event("open_tool_modal", _params, socket) do
    {:noreply,
     assign(socket,
       modal: :tool,
       editing: nil,
       tool_form: to_form(Panel.Tool.changeset(%Panel.Tool{}, %{}))
     )}
  end

  def handle_event("open_tool_modal", %{"id" => id}, socket) do
    t = Panel.get_tool(id)

    {:noreply,
     assign(socket, modal: :tool, editing: t, tool_form: to_form(Panel.Tool.changeset(t, %{})))}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :modal, nil)}
  end

  # --- Bookmark CRUD ------------------------------------------------------
  def handle_event("save_bookmark", %{"bookmark" => attrs}, socket) do
    result =
      case socket.assigns.editing do
        nil -> Panel.create_bookmark(attrs)
        bm -> Panel.update_bookmark(bm, attrs)
      end

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:bookmarks, Panel.list_bookmarks())
         |> assign(:modal, nil)
         |> put_flash(:info, "Bookmark kaydedildi")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, bookmark_form: to_form(changeset))}
    end
  end

  def handle_event("delete_bookmark", %{"id" => id}, socket) do
    with bm when not is_nil(bm) <- Panel.get_bookmark(id) do
      Panel.delete_bookmark(bm)
    end

    {:noreply, assign(socket, :bookmarks, Panel.list_bookmarks())}
  end

  # --- Secret CRUD --------------------------------------------------------
  def handle_event("save_secret", %{"secret" => attrs}, socket) do
    result =
      case socket.assigns.editing do
        nil -> Panel.create_secret(attrs)
        s -> Panel.update_secret(s, attrs)
      end

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:secrets, Panel.list_secrets())
         |> assign(:modal, nil)
         |> put_flash(:info, "Secret kaydedildi")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, secret_form: to_form(changeset))}
    end
  end

  def handle_event("delete_secret", %{"id" => id}, socket) do
    with sec when not is_nil(sec) <- Panel.get_secret(id) do
      Panel.delete_secret(sec)
    end

    {:noreply, assign(socket, :secrets, Panel.list_secrets())}
  end

  def handle_event("toggle_secret", %{"id" => id}, socket) do
    revealed = socket.assigns.revealed_secrets

    revealed =
      if MapSet.member?(revealed, id) do
        MapSet.delete(revealed, id)
      else
        MapSet.put(revealed, id)
      end

    {:noreply, assign(socket, :revealed_secrets, revealed)}
  end

  def handle_event("copy_secret", %{"secret" => secret}, socket) do
    {:noreply, push_event(socket, "copy-to-clipboard", %{text: secret})}
  end

  def handle_event("unlock_vault", %{"password" => pass}, socket) do
    user = socket.assigns.current_user

    if Argon2.verify_pass(pass, user.hashed_password) do
      {:noreply,
       socket
       |> assign(:vault_locked, false)
       |> assign(:vault_password, to_form(%{}))
       |> put_flash(:info, "Vault açıldı")}
    else
      {:noreply,
       socket
       |> assign(:vault_password, to_form(%{}))
       |> put_flash(:error, "Yanlış şifre")}
    end
  end

  # --- Note CRUD ----------------------------------------------------------
  def handle_event("save_note", %{"note" => attrs}, socket) do
    result =
      case socket.assigns.editing do
        nil -> Panel.create_note(attrs)
        n -> Panel.update_note(n, attrs)
      end

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:notes, Panel.list_notes())
         |> assign(:modal, nil)
         |> put_flash(:info, "Not kaydedildi")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, note_form: to_form(changeset))}
    end
  end

  def handle_event("delete_note", %{"id" => id}, socket) do
    with n when not is_nil(n) <- Panel.get_note(id) do
      Panel.delete_note(n)
    end

    {:noreply, assign(socket, :notes, Panel.list_notes())}
  end

  # --- Tool CRUD ----------------------------------------------------------
  def handle_event("save_tool", %{"tool" => attrs}, socket) do
    result =
      case socket.assigns.editing do
        nil -> Panel.create_tool(attrs)
        t -> Panel.update_tool(t, attrs)
      end

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:tools, Panel.list_tools())
         |> assign(:modal, nil)
         |> put_flash(:info, "Araç kaydedildi")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, tool_form: to_form(changeset))}
    end
  end

  def handle_event("delete_tool", %{"id" => id}, socket) do
    with t when not is_nil(t) <- Panel.get_tool(id) do
      Panel.delete_tool(t)
    end

    {:noreply, assign(socket, :tools, Panel.list_tools())}
  end

  def render(assigns) do
    ~H"""
    <EAnyPanelWeb.DashboardLayouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-base-200 flex">
        <!-- Mobile overlay -->
        <%= if @sidebar_open do %>
          <div class="fixed inset-0 bg-black/40 z-40 lg:hidden" phx-click="toggle_sidebar"></div>
        <% end %>
        
    <!-- Sidebar -->
        <aside class={
          "w-64 bg-base-100 min-h-screen p-4 flex flex-col border-r border-base-300 z-50 " <>
            "fixed inset-y-0 left-0 transform transition-transform duration-200 lg:static lg:translate-x-0 " <>
            (if @sidebar_open, do: "translate-x-0", else: "-translate-x-full")
        }>
          <div class="flex items-center justify-between mb-6">
            <div class="flex items-center gap-2">
              <img src={~p"/images/logo.svg"} width="32" alt="e-any" />
              <span class="font-bold text-lg">e-any panel</span>
            </div>
            <button class="btn btn-ghost btn-sm lg:hidden" phx-click="toggle_sidebar">✕</button>
          </div>

          <ul class="menu menu-sm gap-1 flex-1">
            <%= if :dashboard in @visible_tabs do %>
              <li>
                <a href={~p"/admin?tab=dashboard"} class={active(@tab, :dashboard)}>Dashboard</a>
              </li>
            <% end %>

            <%= if :landing in @visible_tabs do %>
              <li><a href={~p"/admin?tab=landing"} class={active(@tab, :landing)}>Landing</a></li>
            <% end %>

            <%= if :proxy_hosts in @visible_tabs or :access_lists in @visible_tabs or :certificates in @visible_tabs do %>
              <li class="menu-title mt-2">Hosts</li>
              <%= if :proxy_hosts in @visible_tabs do %>
                <li>
                  <a href={~p"/admin?tab=proxy_hosts"} class={active(@tab, :proxy_hosts)}>
                    ↳ Proxy Hosts
                  </a>
                </li>
              <% end %>
              <%= if :access_lists in @visible_tabs do %>
                <li>
                  <a href={~p"/admin?tab=access_lists"} class={active(@tab, :access_lists)}>
                    ↳ Access Lists
                  </a>
                </li>
              <% end %>
              <%= if :certificates in @visible_tabs do %>
                <li>
                  <a href={~p"/admin?tab=certificates"} class={active(@tab, :certificates)}>
                    ↳ Certificates
                  </a>
                </li>
              <% end %>
            <% end %>

            <%= if :activity in @visible_tabs do %>
              <li class="menu-title mt-2">Sap</li>
              <li>
                <a href={~p"/admin?tab=activity"} class={active(@tab, :activity)}>
                  Aktivite
                </a>
              </li>
            <% end %>

            <%= if :users in @visible_tabs or :bookmarks in @visible_tabs or :notes in @visible_tabs or :tools in @visible_tabs or :secrets in @visible_tabs or :audit_logs in @visible_tabs or :settings in @visible_tabs do %>
              <li class="menu-title mt-2">Kişisel</li>
              <%= if :users in @visible_tabs do %>
                <li><a href={~p"/admin?tab=users"} class={active(@tab, :users)}>👥 Users</a></li>
              <% end %>
              <%= if :bookmarks in @visible_tabs do %>
                <li>
                  <a href={~p"/admin?tab=bookmarks"} class={active(@tab, :bookmarks)}>📑 Bookmarks</a>
                </li>
              <% end %>
              <%= if :notes in @visible_tabs do %>
                <li><a href={~p"/admin?tab=notes"} class={active(@tab, :notes)}>📝 Notlar</a></li>
              <% end %>
              <%= if :tools in @visible_tabs do %>
                <li><a href={~p"/admin?tab=tools"} class={active(@tab, :tools)}>🧰 Araçlar</a></li>
              <% end %>
              <%= if :secrets in @visible_tabs do %>
                <li><a href={~p"/admin?tab=secrets"} class={active(@tab, :secrets)}>🔐 Secrets</a></li>
              <% end %>
              <%= if :audit_logs in @visible_tabs do %>
                <li>
                  <a href={~p"/admin?tab=audit_logs"} class={active(@tab, :audit_logs)}>
                    📋 Audit Logs
                  </a>
                </li>
              <% end %>
              <%= if :settings in @visible_tabs do %>
                <li>
                  <a href={~p"/admin?tab=settings"} class={active(@tab, :settings)}>⚙️ Settings</a>
                </li>
              <% end %>
            <% end %>
          </ul>

          <div class="mt-auto pt-4 border-t border-base-300 text-xs opacity-60">
            Signed in as {@current_user.email}
            <.form for={%{}} phx-submit="logout" class="mt-2">
              <button type="submit" class="btn btn-ghost btn-xs">Log out</button>
            </.form>
          </div>
        </aside>
        
    <!-- Content -->
        <main class="flex-1 p-4 sm:p-6 overflow-x-auto">
          <div class="flex justify-between items-center mb-4 gap-2">
            <div class="flex items-center gap-2">
              <button class="btn btn-ghost btn-sm lg:hidden" phx-click="toggle_sidebar">☰</button>
              <h1 class="text-xl sm:text-2xl font-semibold">{@tabs[@tab]}</h1>
            </div>
            <div class="flex items-center gap-2">
              <!-- Global search -->
              <.form for={%{}} phx-submit="search" class="flex items-center gap-2">
                <input
                  type="search"
                  name="q"
                  value={@search_term}
                  placeholder="Ara (bookmark, not, secret, araç)…"
                  class="input input-sm input-bordered w-48 sm:w-64"
                />
                <button class="btn btn-sm btn-outline" type="submit">🔍</button>
              </.form>
              <button class="btn btn-sm btn-outline" phx-click="refresh">Yenile</button>
            </div>
          </div>

          <%= if @search_results do %>
            <div class="mb-6 p-4 bg-base-100 rounded-box shadow-sm" id="search-results">
              <div class="flex justify-between items-center mb-3">
                <h2 class="font-semibold">Sonuçlar: "{@search_term}"</h2>
                <button class="btn btn-ghost btn-xs" phx-click={JS.push("search", value: %{q: ""})}>
                  ✕
                </button>
              </div>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                <%= if Enum.empty?(@search_results.tools) and Enum.empty?(@search_results.bookmarks) and Enum.empty?(@search_results.notes) and Enum.empty?(@search_results.secrets) do %>
                  <div class="col-span-full text-center opacity-50 py-6">Sonuç yok</div>
                <% end %>
                <%= for t <- @search_results.tools do %>
                  <div class="flex items-center gap-2 text-sm">
                    <span class="badge badge-info badge-xs shrink-0">Araç</span>
                    <a href={t.url} target="_blank" rel="noopener" class="link link-primary truncate">
                      {t.name}
                    </a>
                  </div>
                <% end %>
                <%= for b <- @search_results.bookmarks do %>
                  <div class="flex items-center gap-2 text-sm">
                    <span class="badge badge-secondary badge-xs shrink-0">Bookmark</span>
                    <a href={b.url} target="_blank" rel="noopener" class="link link-primary truncate">
                      {b.title}
                    </a>
                  </div>
                <% end %>
                <%= for n <- @search_results.notes do %>
                  <div class="flex items-center gap-2 text-sm">
                    <span class="badge badge-warning badge-xs shrink-0">Not</span>
                    <button
                      class="link link-primary truncate"
                      phx-click="open_note_modal"
                      phx-value-id={n.id}
                    >
                      {n.title}
                    </button>
                  </div>
                <% end %>
                <%= for s <- @search_results.secrets do %>
                  <div class="flex items-center gap-2 text-sm">
                    <span class="badge badge-error badge-xs shrink-0">Secret</span>
                    <span class="truncate">{s.title}</span>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

          <%= case @tab do %>
            <% :landing -> %>
              <div class="hero min-h-[60vh]">
                <div class="hero-content text-center max-w-3xl">
                  <div class="flex flex-col items-center">
                    <img src={~p"/images/logo.svg"} width="72" alt="e-any logo" class="mb-6" />
                    <h1 class="text-3xl sm:text-5xl font-bold tracking-tight">
                      e-any.online Yönetim Paneli
                    </h1>
                    <p class="py-6 text-base-content/70 leading-relaxed max-w-xl">
                      Kullanıcılar, araçlar, yer imleri ve gizli anahtarlarınız tek bir
                      güvenli merkezden. Çok faktörlü kimlik doğrulama ve şifreli saklama
                      ile tasarlandı.
                    </p>
                    <div class="flex flex-wrap gap-3 justify-center">
                      <a href={~p"/admin?tab=dashboard"} class="btn btn-primary btn-wide">
                        Panele Git
                      </a>
                    </div>
                    <div class="mt-12 grid grid-cols-1 sm:grid-cols-3 gap-4 w-full max-w-2xl">
                      <div class="stat bg-base-100 rounded-box shadow-sm">
                        <div class="stat-title">Güvenlik</div>
                        <div class="stat-value text-primary text-2xl">2FA</div>
                        <div class="stat-desc">TOTP korumalı</div>
                      </div>
                      <div class="stat bg-base-100 rounded-box shadow-sm">
                        <div class="stat-title">Şifreleme</div>
                        <div class="stat-value text-secondary text-2xl">AES</div>
                        <div class="stat-desc">Cloak vault</div>
                      </div>
                      <div class="stat bg-base-100 rounded-box shadow-sm">
                        <div class="stat-title">Erişim</div>
                        <div class="stat-value text-accent text-2xl">RBAC</div>
                        <div class="stat-desc">Rol tabanlı</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            <% :dashboard -> %>
              <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
                <div class="stat bg-gradient-to-br from-primary/20 to-base-100 rounded-box shadow-sm border border-base-200">
                  <div class="stat-figure text-primary text-2xl">🌐</div>
                  <div class="stat-title">Proxy Hosts</div>
                  <div class="stat-value text-2xl">{length(@npm_proxy_hosts)}</div>
                </div>
                <div class="stat bg-gradient-to-br from-success/20 to-base-100 rounded-box shadow-sm border border-base-200">
                  <div class="stat-figure text-success text-2xl">🔒</div>
                  <div class="stat-title">Certificates</div>
                  <div class="stat-value text-2xl">{length(@npm_certificates)}</div>
                </div>
                <div class="stat bg-gradient-to-br from-info/20 to-base-100 rounded-box shadow-sm border border-base-200">
                  <div class="stat-figure text-info text-2xl">👥</div>
                  <div class="stat-title">App Users</div>
                  <div class="stat-value text-2xl">{length(@app_users)}</div>
                </div>
                <div class="stat bg-gradient-to-br from-warning/20 to-base-100 rounded-box shadow-sm border border-base-200">
                  <div class="stat-figure text-warning text-2xl">📜</div>
                  <div class="stat-title">Audit Logs</div>
                  <div class="stat-value text-2xl">{length(@npm_audit_logs)}</div>
                </div>
              </div>

              <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4 mt-4">
                <div class="stat bg-base-100 rounded-box shadow-sm border border-base-200">
                  <div class="stat-title text-base-content/70">📑 Bookmarks</div>
                  <div class="stat-value text-2xl">{length(@bookmarks)}</div>
                </div>
                <div class="stat bg-base-100 rounded-box shadow-sm border border-base-200">
                  <div class="stat-title text-base-content/70">📝 Notlar</div>
                  <div class="stat-value text-2xl">{length(@notes)}</div>
                </div>
                <div class="stat bg-base-100 rounded-box shadow-sm border border-base-200">
                  <div class="stat-title text-base-content/70">🔐 Secrets</div>
                  <div class="stat-value text-2xl">{length(@secrets)}</div>
                </div>
                <div class="stat bg-base-100 rounded-box shadow-sm border border-base-200">
                  <div class="stat-title text-base-content/70">🧰 Araçlar</div>
                  <div class="stat-value text-2xl">{length(@tools)}</div>
                </div>
              </div>

              <%= if @access_logs != [] do %>
                <div class="card bg-base-100 shadow-sm border border-base-200 mt-4">
                  <div class="card-body p-4">
                    <h3 class="card-title text-base mb-2">🕒 Son Erişimler</h3>
                    <div class="overflow-x-auto">
                      <table class="table table-sm">
                        <thead>
                          <tr>
                            <th>Zaman</th>
                            <th>Nesne</th>
                            <th>İşlem</th>
                            <th>Kullanıcı</th>
                          </tr>
                        </thead>
                        <tbody>
                          <%= for l <- @access_logs do %>
                            <tr>
                              <td class="text-xs opacity-70">{l.accessed_at}</td>
                              <td class="text-xs">
                                {(l.secret_id && "secret") || (l.note_id && "note") || "panel"}
                              </td>
                              <td class="text-xs">erişim</td>
                              <td class="text-xs">{l.user_id}</td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  </div>
                </div>
              <% end %>
            <% :proxy_hosts -> %>
              <!-- Card view (mobile + desktop grid) -->
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 mb-6">
                <%= for h <- @npm_proxy_hosts do %>
                  <div class={"card bg-base-100 shadow-sm hover:shadow-lg hover:-translate-y-0.5 transition-all duration-200 border-t-4 " <> (if h.ssl == "Let's Encrypt", do: "border-primary", else: "border-base-300")}>
                    <div class="card-body p-4">
                      <div class="flex items-start justify-between gap-2">
                        <h3 class="card-title text-base leading-tight">
                          <a
                            href={"https://#{h.domain}"}
                            class="link link-primary hover:link-accent"
                            target="_blank"
                            rel="noopener"
                          >
                            {h.domain}
                          </a>
                        </h3>
                        <span class="badge badge-success gap-1 shrink-0">
                          <span class="w-2 h-2 rounded-full bg-success inline-block"></span>Online
                        </span>
                      </div>
                      <p class="text-xs font-mono opacity-60 truncate mt-1">{h.forward_url}</p>
                      <div class="flex flex-wrap gap-1.5 mt-3">
                        <span class={"badge badge-sm " <> (if h.ssl == "Let's Encrypt", do: "badge-primary", else: "badge-ghost")}>
                          {if h.ssl == "Let's Encrypt", do: "🔒 ", else: "🌐 "}{h.ssl}
                        </span>
                        <span class="badge badge-sm badge-outline">{h.access}</span>
                        <%= if h.block_exploits do %>
                          <span class="badge badge-sm badge-warning">Exploit Guard</span>
                        <% end %>
                      </div>
                      <p class="text-[11px] opacity-40 mt-3">Created: {h.created_on}</p>
                    </div>
                  </div>
                <% end %>
              </div>
              
    <!-- Table view (desktop) -->
              <div class="overflow-x-auto hidden lg:block">
                <table class="table table-zebra">
                  <thead>
                    <tr>
                      <th>Domain</th>
                      <th>SSL</th>
                      <th>Access</th>
                      <th>Hedef</th>
                      <th>Created</th>
                      <th>Durum</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for h <- @npm_proxy_hosts do %>
                      <tr>
                        <td>
                          <a href={"https://#{h.domain}"} class="link" target="_blank" rel="noopener">
                            {h.domain}
                          </a>
                        </td>
                        <td>{h.ssl}</td>
                        <td>{h.access}</td>
                        <td class="text-sm opacity-70">{h.forward_url}</td>
                        <td class="text-sm opacity-70">{h.created_on}</td>
                        <td><span class="badge badge-success badge-sm">Online</span></td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% :access_lists -> %>
              <table class="table table-zebra">
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Name</th>
                    <th>Clients</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for a <- @npm_access_lists do %>
                    <tr>
                      <td>{a.id}</td>
                      <td>{a.name}</td>
                      <td>{a.clients}</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            <% :certificates -> %>
              <table class="table table-zebra">
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Domain</th>
                    <th>Expires</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for c <- @npm_certificates do %>
                    <tr>
                      <td>{c.id}</td>
                      <td>{c.domain}</td>
                      <td class="text-sm opacity-70">{c.expires_on}</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            <% :users -> %>
              <div class="space-y-6">
                <div>
                  <h2 class="text-lg font-semibold mb-2">NPM Users</h2>
                  <table class="table table-zebra">
                    <thead>
                      <tr>
                        <th>ID</th>
                        <th>Email</th>
                        <th>Name</th>
                        <th>Status</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for u <- @npm_users do %>
                        <tr>
                          <td>{u.id}</td>
                          <td>{u.email}</td>
                          <td>{u.name}</td>
                          <td>{if u.disabled, do: "Disabled", else: "Active"}</td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
                <div>
                  <h2 class="text-lg font-semibold mb-2">Panel Users</h2>
                  <p class="text-xs opacity-60 mb-2">
                    Rol: <b>admin</b>
                    tüm sekmeleri görür · <b>manager</b>
                    Dashboard + Sap · <b>viewer</b>
                    sadece atanan sekmeler. "İzinler" butonu ile sekme bazlı yetki verilir.
                  </p>
                  <table class="table table-zebra">
                    <thead>
                      <tr>
                        <th>ID</th>
                        <th>Email</th>
                        <th>Rol</th>
                        <th>2FA</th>
                        <th>İzinler</th>
                        <th>Sekmeler</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for u <- @app_users do %>
                        <tr>
                          <td>{u.id}</td>
                          <td>{u.email}</td>
                          <td>
                            <.form
                              for={%{}}
                              phx-submit="update_user_role"
                              phx-value-user_id={u.id}
                              class="inline"
                            >
                              <select
                                name="role"
                                class="select select-xs select-bordered"
                                phx-change="update_user_role"
                                phx-value-user_id={u.id}
                              >
                                <%= for r <- ["viewer", "manager", "admin"] do %>
                                  <option value={r} selected={u.role == r}>{r}</option>
                                <% end %>
                              </select>
                            </.form>
                          </td>
                          <td>{if u.totp_secret, do: "✓", else: "—"}</td>
                          <td>
                            <button
                              class="btn btn-xs btn-outline"
                              phx-click="toggle_user_perms"
                              phx-value-user_id={u.id}
                            >
                              İzinler
                            </button>
                            <%= if @editing_perms_user == u.id do %>
                              <div class="mt-2 p-2 bg-base-200 rounded">
                                <p class="text-xs mb-1">Sekme bazlı yetki:</p>
                                <.form
                                  for={%{}}
                                  phx-submit="save_user_perms"
                                  phx-value-user_id={u.id}
                                >
                                  <div class="flex flex-wrap gap-1">
                                    <%= for t <- Keyword.keys(@tabs) do %>
                                      <label class="flex items-center gap-1 text-xs">
                                        <input
                                          type="checkbox"
                                          name="tabs[]"
                                          value={t}
                                          checked={Accounts.can_access_tab?(u, to_string(t))}
                                          class="checkbox checkbox-xs"
                                        />
                                        {t}
                                      </label>
                                    <% end %>
                                  </div>
                                  <button type="submit" class="btn btn-xs btn-primary mt-2">
                                    Kaydet
                                  </button>
                                </.form>
                              </div>
                            <% end %>
                          </td>
                          <td class="text-xs opacity-60">
                            <%= case u.role do %>
                              <% "admin" -> %>
                                tümü
                              <% "manager" -> %>
                                dashboard, sap
                              <% _ -> %>
                                <%= Accounts.allowed_tabs_for(u) |> case do %>
                                  <% :all -> %>
                                    tümü
                                  <% tabs when is_list(tabs) -> %>
                                    Enum.join(tabs, ", ")
                                  <% _ -> %>
                                    —
                                <% end %>
                            <% end %>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
            <% :audit_logs -> %>
              <table class="table table-zebra">
                <thead>
                  <tr>
                    <th>Time</th>
                    <th>Object</th>
                    <th>Action</th>
                    <th>Actor</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for l <- @npm_audit_logs do %>
                    <tr>
                      <td class="text-sm opacity-70">{l.time}</td>
                      <td>{l.object}</td>
                      <td>{l.action}</td>
                      <td class="text-sm opacity-70">{l.actor}</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            <% :notes -> %>
              <div class="flex justify-end mb-4">
                <button class="btn btn-primary btn-sm" phx-click="open_note_modal">
                  + Yeni Not
                </button>
              </div>
              <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
                <%= for n <- @notes do %>
                  <div class={"card bg-base-100 shadow-sm hover:shadow-md transition-shadow border-l-4 #{if n.is_critical, do: "border-error", else: "border-info"}"}>
                    <div class="card-body p-4">
                      <div class="flex items-start justify-between gap-2">
                        <h3 class="card-title text-base">
                          {if n.is_critical, do: "🔒 ", else: "📝 "}{n.title}
                        </h3>
                        <div class="flex gap-1">
                          <button
                            class="btn btn-ghost btn-xs"
                            phx-click="open_note_modal"
                            phx-value-id={n.id}
                            title="Düzenle"
                          >
                            ✏️
                          </button>
                          <button
                            class="btn btn-ghost btn-xs text-error"
                            phx-click="delete_note"
                            phx-value-id={n.id}
                            phx-confirm="Silinsin mi?"
                            title="Sil"
                          >
                            ✕
                          </button>
                        </div>
                      </div>
                      <%= if n.body do %>
                        <p class="text-sm opacity-70 whitespace-pre-wrap line-clamp-4 mt-2">
                          {n.body}
                        </p>
                      <% end %>
                      <%= if n.is_critical do %>
                        <span class="badge badge-error badge-sm mt-2 w-fit">Kritik</span>
                      <% end %>
                    </div>
                  </div>
                <% end %>
                <%= if Enum.empty?(@notes) do %>
                  <div class="col-span-full text-center opacity-50 py-10">
                    Henüz not yok. "+ Yeni Not" ile ekleyin.
                  </div>
                <% end %>
              </div>
            <% :tools -> %>
              <div class="flex justify-end mb-4">
                <button class="btn btn-primary btn-sm" phx-click="open_tool_modal">
                  + Yeni Araç
                </button>
              </div>
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
                <%= for t <- Enum.filter(@tools, & &1.is_active) do %>
                  <div class="card bg-base-100 shadow-sm hover:shadow-md transition-shadow border-t-4 border-success">
                    <div class="card-body p-4">
                      <div class="flex items-start justify-between gap-2">
                        <h3 class="card-title text-base">
                          <a href={t.url} target="_blank" rel="noopener" class="link link-primary">
                            {t.name}
                          </a>
                        </h3>
                        <div class="flex gap-1">
                          <button
                            class="btn btn-ghost btn-xs"
                            phx-click="open_tool_modal"
                            phx-value-id={t.id}
                            title="Düzenle"
                          >
                            ✏️
                          </button>
                          <button
                            class="btn btn-ghost btn-xs text-error"
                            phx-click="delete_tool"
                            phx-value-id={t.id}
                            phx-confirm="Silinsin mi?"
                            title="Sil"
                          >
                            ✕
                          </button>
                        </div>
                      </div>
                      <%= if t.category do %>
                        <span class="badge badge-sm badge-success mt-2 w-fit">{t.category}</span>
                      <% end %>
                    </div>
                  </div>
                <% end %>
                <%= if Enum.empty?(Enum.filter(@tools, & &1.is_active)) do %>
                  <div class="col-span-full text-center opacity-50 py-10">
                    Henüz aktif araç yok. "+ Yeni Araç" ile ekleyin.
                  </div>
                <% end %>
              </div>
            <% :bookmarks -> %>
              <div class="flex justify-end mb-4">
                <button class="btn btn-primary btn-sm" phx-click="open_bookmark_modal">
                  + Yeni Bookmark
                </button>
              </div>
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
                <%= for bm <- @bookmarks do %>
                  <div class="card bg-base-100 shadow-sm hover:shadow-md transition-shadow">
                    <div class="card-body p-4">
                      <div class="flex items-start justify-between gap-2">
                        <h3 class="card-title text-base truncate">
                          <a href={bm.url} target="_blank" rel="noopener" class="link link-primary">
                            {bm.title}
                          </a>
                        </h3>
                        <div class="flex gap-1 shrink-0">
                          <button
                            class="btn btn-ghost btn-xs"
                            phx-click="open_bookmark_modal"
                            phx-value-id={bm.id}
                            title="Düzenle"
                          >
                            ✏️
                          </button>
                          <button
                            class="btn btn-ghost btn-xs text-error"
                            phx-click="delete_bookmark"
                            phx-value-id={bm.id}
                            phx-confirm="Silinsin mi?"
                          >
                            ✕
                          </button>
                        </div>
                      </div>
                      <p class="text-sm opacity-70 truncate">{bm.url}</p>
                      <%= if bm.category do %>
                        <span class="badge badge-sm badge-outline mt-2 w-fit">{bm.category}</span>
                      <% end %>
                      <%= if bm.note do %>
                        <p class="text-xs opacity-50 mt-2">{bm.note}</p>
                      <% end %>
                    </div>
                  </div>
                <% end %>
                <%= if Enum.empty?(@bookmarks) do %>
                  <div class="col-span-full text-center opacity-50 py-10">
                    Henüz bookmark yok. "+ Yeni Bookmark" ile ekleyin.
                  </div>
                <% end %>
              </div>
            <% :secrets -> %>
              <div class="flex justify-end mb-4">
                <button class="btn btn-primary btn-sm" phx-click="open_secret_modal">
                  + Yeni Secret
                </button>
              </div>
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                <%= for s <- @secrets do %>
                  <div class="card bg-base-100 shadow-sm hover:shadow-md transition-shadow border-l-4 border-warning">
                    <div class="card-body p-4">
                      <div class="flex items-start justify-between gap-2">
                        <div>
                          <h3 class="card-title text-base">{s.title}</h3>
                          <%= if s.url do %>
                            <a
                              href={s.url}
                              target="_blank"
                              rel="noopener"
                              class="text-xs link link-primary"
                            >
                              {s.url}
                            </a>
                          <% end %>
                        </div>
                        <div class="flex gap-1">
                          <button
                            class="btn btn-ghost btn-xs"
                            phx-click="open_secret_modal"
                            phx-value-id={s.id}
                            title="Düzenle"
                          >
                            ✏️
                          </button>
                          <button
                            class="btn btn-ghost btn-xs text-error"
                            phx-click="delete_secret"
                            phx-value-id={s.id}
                            phx-confirm="Silinsin mi?"
                          >
                            ✕
                          </button>
                        </div>
                      </div>
                      <%= if s.username do %>
                        <p class="text-sm mt-1"><span class="opacity-50">User:</span> {s.username}</p>
                      <% end %>
                      <%= if s.password do %>
                        <div class="mt-2">
                          <span class="opacity-50 text-sm">Pass:</span>
                          <div class="flex items-center gap-2 mt-1">
                            <%= if s.is_critical and @vault_locked do %>
                              <code class="text-sm bg-base-200 px-2 py-1 rounded font-mono break-all">
                                🔒 kilitli
                              </code>
                            <% else %>
                              <code class="text-sm bg-base-200 px-2 py-1 rounded font-mono break-all">
                                {if MapSet.member?(@revealed_secrets, s.id),
                                  do: s.password,
                                  else: String.duplicate("•", min(String.length(s.password), 16))}
                              </code>
                              <button
                                class="btn btn-ghost btn-xs"
                                phx-click="toggle_secret"
                                phx-value-id={s.id}
                                title={
                                  if MapSet.member?(@revealed_secrets, s.id),
                                    do: "Gizle",
                                    else: "Göster"
                                }
                              >
                                {if MapSet.member?(@revealed_secrets, s.id), do: "🙈", else: "👁"}
                              </button>
                              <button
                                class="btn btn-ghost btn-xs"
                                id={"copy-secret-#{s.id}"}
                                phx-hook="CopyButton"
                                data-copy={s.password}
                                title="Kopyala"
                              >
                                📋
                              </button>
                            <% end %>
                          </div>
                        </div>
                      <% end %>
                      <%= if s.is_critical do %>
                        <span class="badge badge-warning badge-sm mt-2">Kritik</span>
                      <% end %>
                    </div>
                  </div>
                <% end %>
                <%= if Enum.empty?(@secrets) do %>
                  <div class="col-span-full text-center opacity-50 py-10">
                    Henüz secret yok. "+ Yeni Secret" ile ekleyin.
                  </div>
                <% end %>
              </div>
            <% :activity -> %>
              <div class="flex justify-between items-center mb-4">
                <h2 class="text-lg font-semibold">Aktivite (Sap)</h2>
                <button class="btn btn-sm btn-outline" phx-click="refresh">Yenile</button>
              </div>
              <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
                <div class="card bg-base-100 shadow-sm">
                  <div class="card-body p-4">
                    <h3 class="card-title text-base mb-2">🔐 Erişim Logları</h3>
                    <div class="overflow-x-auto">
                      <table class="table table-zebra table-sm">
                        <thead>
                          <tr>
                            <th>Zaman</th>
                            <th>Kullanıcı</th>
                            <th>Nesne</th>
                            <th>İşlem</th>
                          </tr>
                        </thead>
                        <tbody>
                          <%= for l <- @access_logs do %>
                            <tr>
                              <td class="text-xs opacity-70">{l.accessed_at}</td>
                              <td class="text-xs">{l.user_id}</td>
                              <td class="text-xs">
                                {(l.secret_id && "secret") || (l.note_id && "note") || "panel"}
                              </td>
                              <td class="text-xs">erişim</td>
                            </tr>
                          <% end %>
                          <%= if Enum.empty?(@access_logs) do %>
                            <tr>
                              <td colspan="4" class="text-center opacity-50 py-4">
                                Henüz erişim kaydı yok
                              </td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  </div>
                </div>

                <div class="card bg-base-100 shadow-sm">
                  <div class="card-body p-4">
                    <h3 class="card-title text-base mb-2">🆔 NPM Activity</h3>
                    <div class="overflow-x-auto">
                      <table class="table table-zebra table-sm">
                        <thead>
                          <tr>
                            <th>Zaman</th>
                            <th>Nesne</th>
                            <th>İşlem</th>
                            <th>Actor</th>
                          </tr>
                        </thead>
                        <tbody>
                          <%= for l <- @npm_audit_logs do %>
                            <tr>
                              <td class="text-xs opacity-70">{l.time}</td>
                              <td class="text-xs">{l.object}</td>
                              <td class="text-xs">{l.action}</td>
                              <td class="text-xs opacity-70">{l.actor}</td>
                            </tr>
                          <% end %>
                          <%= if Enum.empty?(@npm_audit_logs) do %>
                            <tr>
                              <td colspan="4" class="text-center opacity-50 py-4">
                                NPM audit kaydı yok
                              </td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  </div>
                </div>
              </div>
            <% :settings -> %>
              <div class="max-w-lg space-y-4">
                <div class="alert alert-info">Panel ayarları buradan yönetilecek (yakında).</div>
                <div class="stat bg-base-100 rounded-box">
                  <div class="stat-title">Tools</div>
                  <div class="stat-value">{length(@tools)}</div>
                </div>
                <div class="stat bg-base-100 rounded-box">
                  <div class="stat-title">Bookmarks</div>
                  <div class="stat-value">{length(@bookmarks)}</div>
                </div>
                <div class="stat bg-base-100 rounded-box">
                  <div class="stat-title">Secrets</div>
                  <div class="stat-value">{length(@secrets)}</div>
                </div>
                <div class="stat bg-base-100 rounded-box">
                  <div class="stat-title">Access Logs</div>
                  <div class="stat-value">{length(@access_logs)}</div>
                </div>
              </div>
          <% end %>
          
    <!-- Modals -->
          <%= if @modal == :bookmark do %>
            <dialog class="modal modal-open">
              <div class="modal-box">
                <h3 class="text-lg font-semibold mb-4">
                  {if @editing, do: "Bookmark'ı Düzenle", else: "Yeni Bookmark"}
                </h3>
                <.form for={@bookmark_form} phx-submit="save_bookmark" phx-change="save_bookmark">
                  <.input field={@bookmark_form[:title]} label="Başlık" required />
                  <.input field={@bookmark_form[:url]} label="URL" type="url" required />
                  <.input field={@bookmark_form[:category]} label="Kategori" />
                  <.input field={@bookmark_form[:note]} label="Not" type="textarea" />
                  <div class="modal-action">
                    <button type="button" class="btn" phx-click="close_modal">İptal</button>
                    <button type="submit" class="btn btn-primary">Kaydet</button>
                  </div>
                </.form>
              </div>
              <form method="dialog" class="modal-backdrop">
                <button phx-click="close_modal">close</button>
              </form>
            </dialog>
          <% end %>

          <%= if @modal == :note do %>
            <dialog class="modal modal-open">
              <div class="modal-box">
                <h3 class="text-lg font-semibold mb-4">
                  {if @editing, do: "Notu Düzenle", else: "Yeni Not"}
                </h3>
                <.form for={@note_form} phx-submit="save_note" phx-change="save_note">
                  <.input field={@note_form[:title]} label="Başlık" required />
                  <.input field={@note_form[:body]} label="İçerik" type="textarea" />
                  <label class="label cursor-pointer justify-start gap-2 mt-2">
                    <.input
                      field={@note_form[:is_critical]}
                      type="checkbox"
                      class="checkbox checkbox-error"
                    />
                    <span class="label-text">Kritik (vault şifresiyle korunur)</span>
                  </label>
                  <div class="modal-action">
                    <button type="button" class="btn" phx-click="close_modal">İptal</button>
                    <button type="submit" class="btn btn-primary">Kaydet</button>
                  </div>
                </.form>
              </div>
              <form method="dialog" class="modal-backdrop">
                <button phx-click="close_modal">close</button>
              </form>
            </dialog>
          <% end %>

          <%= if @modal == :tool do %>
            <dialog class="modal modal-open">
              <div class="modal-box">
                <h3 class="text-lg font-semibold mb-4">
                  {if @editing, do: "Aracı Düzenle", else: "Yeni Araç"}
                </h3>
                <.form for={@tool_form} phx-submit="save_tool" phx-change="save_tool">
                  <.input field={@tool_form[:name]} label="Ad" required />
                  <.input field={@tool_form[:url]} label="URL" type="url" />
                  <.input field={@tool_form[:category]} label="Kategori" />
                  <label class="label cursor-pointer justify-start gap-2 mt-2">
                    <.input
                      field={@tool_form[:is_active]}
                      type="checkbox"
                      class="checkbox checkbox-success"
                    />
                    <span class="label-text">Aktif</span>
                  </label>
                  <div class="modal-action">
                    <button type="button" class="btn" phx-click="close_modal">İptal</button>
                    <button type="submit" class="btn btn-primary">Kaydet</button>
                  </div>
                </.form>
              </div>
              <form method="dialog" class="modal-backdrop">
                <button phx-click="close_modal">close</button>
              </form>
            </dialog>
          <% end %>

          <%= if @modal == :secret do %>
            <dialog class="modal modal-open">
              <div class="modal-box">
                <h3 class="text-lg font-semibold mb-4">
                  {if @editing, do: "Secret'ı Düzenle", else: "Yeni Secret"}
                </h3>
                <.form for={@secret_form} phx-submit="save_secret" phx-change="save_secret">
                  <.input field={@secret_form[:title]} label="Başlık" required />
                  <.input field={@secret_form[:username]} label="Kullanıcı Adı" />
                  <.input field={@secret_form[:password]} label="Şifre" type="password" />
                  <.input field={@secret_form[:url]} label="URL" type="url" />
                  <.input field={@secret_form[:notes]} label="Notlar" type="textarea" />
                  <label class="label cursor-pointer justify-start gap-2 mt-2">
                    <.input
                      field={@secret_form[:is_critical]}
                      type="checkbox"
                      class="checkbox checkbox-warning"
                    />
                    <span class="label-text">Kritik (vault re-auth gerekir)</span>
                  </label>
                  <div class="modal-action">
                    <button type="button" class="btn" phx-click="close_modal">İptal</button>
                    <button type="submit" class="btn btn-primary">Kaydet</button>
                  </div>
                </.form>
              </div>
              <form method="dialog" class="modal-backdrop">
                <button phx-click="close_modal">close</button>
              </form>
            </dialog>
          <% end %>

          <%= if @vault_locked and @tab == :secrets and Enum.any?(@secrets, & &1.is_critical) and not @vault_unlock_modal do %>
            <div class="alert alert-warning shadow-lg fixed bottom-4 right-4 z-50 max-w-sm">
              <div>
                <h3 class="font-bold">🔐 Vault kilitli</h3>
                <p class="text-xs">Kritik şifreleri görmek için şifreni doğrula.</p>
              </div>
              <.form for={@vault_password} phx-submit="unlock_vault" class="flex gap-2 mt-2">
                <input
                  type="password"
                  name="password"
                  placeholder="Şifren"
                  class="input input-sm input-bordered"
                  required
                />
                <button type="submit" class="btn btn-sm btn-warning">Aç</button>
              </.form>
            </div>
          <% end %>
        </main>
      </div>
    </EAnyPanelWeb.DashboardLayouts.app>
    """
  end

  # --- User role management (admin only) ------------------------------------
  def handle_event("toggle_user_perms", %{"user_id" => id}, socket) do
    current = socket.assigns[:editing_perms_user]
    new = if current == id, do: nil, else: id
    {:noreply, assign(socket, :editing_perms_user, new)}
  end

  def handle_event("update_user_role", %{"user_id" => id, "role" => role}, socket) do
    if socket.assigns.current_user.role == "admin" do
      with user when not is_nil(user) <- Accounts.get_user(id) do
        allowed =
          case role do
            "admin" -> "[]"
            "manager" -> "[]"
            "viewer" -> Jason.encode!(socket.assigns[:perms_for] || [])
            _ -> "[]"
          end

        Accounts.update_user_roles(user, %{role: role, allowed_tabs: allowed})
      end

      {:noreply, assign(socket, :app_users, Accounts.list_users())}
    else
      {:noreply, put_flash(socket, :error, "Sadece admin rol değiştirebilir.")}
    end
  end

  def handle_event("save_user_perms", %{"user_id" => id, "tabs" => tabs}, socket) do
    if socket.assigns.current_user.role == "admin" do
      with user when not is_nil(user) <- Accounts.get_user(id) do
        Accounts.update_user_roles(user, %{role: user.role, allowed_tabs: Jason.encode!(tabs)})
      end

      {:noreply, assign(socket, :app_users, Accounts.list_users())}
    else
      {:noreply, put_flash(socket, :error, "Sadece admin rol değiştirebilir.")}
    end
  end

  # --- Helpers --------------------------------------------------------------
  defp visible_tabs_for(%{role: "admin"}), do: Keyword.keys(@tabs)
  defp visible_tabs_for(%{role: "manager"} = user), do: visible_tabs_from_allowed(user)
  defp visible_tabs_for(%{role: "viewer"} = user), do: visible_tabs_from_allowed(user)

  defp visible_tabs_for(_), do: [:dashboard]

  # Accounts.allowed_tabs_for string list döner -> atomlara çevir ve @tabs'ta
  # olmayanları ele. Admin için Accounts zaten tüm tabları döndürür.
  defp visible_tabs_from_allowed(user) do
    allowed =
      case Accounts.allowed_tabs_for(user) do
        :all -> Keyword.keys(@tabs)
        tabs when is_list(tabs) -> Enum.map(tabs, &String.to_atom/1)
        _ -> []
      end

    (allowed ++ @default_viewer_tabs)
    |> Enum.uniq()
    |> Enum.filter(&(&1 in Keyword.keys(@tabs)))
  end

  defp active(tab, tab), do: "active"
  defp active(_current, _tab), do: ""
end
