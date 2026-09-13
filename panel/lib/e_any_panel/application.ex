defmodule EAnyPanel.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      EAnyPanelWeb.Telemetry,
      EAnyPanel.Repo,
      EAnyPanel.Vault,
      {DNSCluster, query: Application.get_env(:e_any_panel, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: EAnyPanel.PubSub},
      {Finch, name: Finch},
      # Start a worker by calling: EAnyPanel.Worker.start_link(arg)
      # {EAnyPanel.Worker, arg},
      # Start to serve requests, typically the last entry
      EAnyPanelWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EAnyPanel.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EAnyPanelWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
