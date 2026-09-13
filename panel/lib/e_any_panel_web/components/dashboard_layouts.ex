defmodule EAnyPanelWeb.DashboardLayouts do
  @moduledoc """
  Layout for the admin dashboard shell.
  The root HTML skeleton is applied by the router's root layout, so this
  only provides a full-width wrapper (no max-w-2xl centering container).
  """
  use EAnyPanelWeb, :html

  embed_templates "dashboard_layouts/*"

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    {render_slot(@inner_block)}
    """
  end
end
