defmodule EAnyPanelWeb.FeedController do
  @moduledoc """
  Feed — agentandbot.com oda sisteminden içerik akışı.
  Mesajlar kanallara (agentandbot, e-any) göre filtrelenir.
  """
  use EAnyPanelWeb, :controller

  alias EAnyPanel.Feed

  def index(conn, params) do
    site = Map.get(params, "site", "e-any")
    page = Map.get(params, "page", "1") |> String.to_integer()
    per_page = 10

    feed_data = Feed.fetch_feed(site, page, per_page)
    render(conn, :index, feed: feed_data, site: site)
  end

  def show(conn, %{"slug" => slug}) do
    # Feed API'den slug'a göre tekil post çek
    # Şimdilik ilk mesajı getirelim (basit implementasyon)
    feed_data = EAnyPanel.Feed.fetch_feed("e-any", 1, 50)
    post = Enum.find(feed_data.posts, fn p -> p.slug == slug end)

    case post do
      nil -> render(conn, :show, post: nil, site: "e-any")
      p -> render(conn, :show, post: p, site: "e-any")
    end
  end
end
