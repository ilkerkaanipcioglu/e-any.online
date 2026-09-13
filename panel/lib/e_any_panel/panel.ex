defmodule EAnyPanel.Panel do
  @moduledoc """
  Panel data: tools (link registry), bookmarks, notes, secrets and access logs.
  Sensitive fields are encrypted via Cloak; this context only loads/decrypts
  them, the UI enforces the re-auth gate before rendering.
  """
  import Ecto.Query, warn: false
  alias EAnyPanel.Repo
  alias EAnyPanel.Panel.{Tool, Bookmark, Note, Secret, AccessLog}

  # --- Tools ---------------------------------------------------------------
  def list_tools(active_only \\ false)
  def list_tools(true), do: Repo.all(from t in Tool, where: t.is_active, order_by: t.category)
  def list_tools(false), do: Repo.all(from t in Tool, order_by: t.category)

  def get_tool(id), do: Repo.get(Tool, id)
  def create_tool(attrs), do: %Tool{} |> Tool.changeset(attrs) |> Repo.insert()
  def update_tool(%Tool{} = t, attrs), do: t |> Tool.changeset(attrs) |> Repo.update()
  def delete_tool(%Tool{} = t), do: Repo.delete(t)

  # --- Bookmarks -----------------------------------------------------------
  def list_bookmarks, do: Repo.all(from b in Bookmark, order_by: b.category)
  def get_bookmark(id), do: Repo.get(Bookmark, id)
  def create_bookmark(attrs), do: %Bookmark{} |> Bookmark.changeset(attrs) |> Repo.insert()
  def update_bookmark(%Bookmark{} = b, attrs), do: b |> Bookmark.changeset(attrs) |> Repo.update()
  def delete_bookmark(%Bookmark{} = b), do: Repo.delete(b)

  # --- Notes ---------------------------------------------------------------
  def list_notes, do: Repo.all(from n in Note, order_by: n.title)
  def get_note(id), do: Repo.get(Note, id)
  def create_note(attrs), do: %Note{} |> Note.changeset(attrs) |> Repo.insert()
  def update_note(%Note{} = n, attrs), do: n |> Note.changeset(attrs) |> Repo.update()
  def delete_note(%Note{} = n), do: Repo.delete(n)

  # --- Secrets -------------------------------------------------------------
  def list_secrets, do: Repo.all(from s in Secret, order_by: s.title)
  def get_secret(id), do: Repo.get(Secret, id)
  def create_secret(attrs), do: %Secret{} |> Secret.changeset(attrs) |> Repo.insert()
  def update_secret(%Secret{} = s, attrs), do: s |> Secret.changeset(attrs) |> Repo.update()
  def delete_secret(%Secret{} = s), do: Repo.delete(s)

  # --- Access logs ---------------------------------------------------------
  def log_access(user_id, kind, id, ip) when kind in [:secret, :note] do
    field = if kind == :secret, do: :secret_id, else: :note_id
    attrs = %{user_id: user_id, ip_address: ip, accessed_at: DateTime.utc_now()}
    attrs = Map.put(attrs, field, id)

    %AccessLog{}
    |> AccessLog.changeset(attrs)
    |> Repo.insert()
  end

  def recent_access(user_id \\ nil, limit \\ 50) do
    base = from a in AccessLog, order_by: [desc: a.accessed_at], limit: ^limit
    if user_id, do: Repo.all(from a in base, where: a.user_id == ^user_id), else: Repo.all(base)
  end

  @doc "Birleşik aktivite akışı: access_logs (secret/note erişimleri)."
  def activity_feed(limit \\ 30) do
    Repo.all(from a in AccessLog, order_by: [desc: a.accessed_at], limit: ^limit)
    |> Enum.map(fn log ->
      kind =
        cond do
          log.secret_id -> "secret"
          log.note_id -> "note"
          true -> "panel"
        end

      %{
        time: log.accessed_at,
        actor: log.user_id,
        object: kind,
        action: "accessed",
        detail: "ip: #{log.ip_address || "-"}"
      }
    end)
  end

  # --- Search (titles / urls / categories only; bodies are encrypted) ------
  def search(""), do: %{tools: [], bookmarks: [], notes: [], secrets: []}
  def search(nil), do: %{tools: [], bookmarks: [], notes: [], secrets: []}

  def search(term) do
    like = "%#{String.trim(term)}%"

    tools =
      Repo.all(
        from t in Tool,
          where:
            t.is_active and
              (ilike(t.name, ^like) or ilike(t.url, ^like) or ilike(t.category, ^like))
      )

    bookmarks =
      Repo.all(
        from b in Bookmark,
          where: ilike(b.title, ^like) or ilike(b.url, ^like) or ilike(b.category, ^like)
      )

    tool_ids = Enum.map(tools, & &1.id)
    bookmark_ids = Enum.map(bookmarks, & &1.id)

    notes =
      Repo.all(from n in Note, where: ilike(n.title, ^like))
      |> Kernel.++(
        # Encrypted body araması: session'da decrypt edip eşleşenleri bul
        if String.length(String.trim(term)) >= 2 do
          Repo.all(Note)
          |> Enum.filter(fn n ->
            body = n.body && EAnyPanel.Vault.decrypt(n.body)
            body && String.downcase(body) =~ String.downcase(String.trim(term))
          end)
        else
          []
        end
      )
      |> Enum.uniq_by(& &1.id)

    secrets = Repo.all(from s in Secret, where: ilike(s.title, ^like))

    %{
      tools: tools,
      bookmarks: bookmarks,
      notes: notes,
      secrets: secrets,
      tool_ids: tool_ids,
      bookmark_ids: bookmark_ids
    }
  end
end
