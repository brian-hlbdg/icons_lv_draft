defmodule IconsLvDraft.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      IconsLvDraftWeb.Telemetry,
      IconsLvDraft.Repo,
      {DNSCluster, query: Application.get_env(:icons_lv_draft, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: IconsLvDraft.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: IconsLvDraft.Finch},
      # Start a worker by calling: IconsLvDraft.Worker.start_link(arg)
      # {IconsLvDraft.Worker, arg},
      # Start to serve requests, typically the last entry
      IconsLvDraftWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: IconsLvDraft.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    IconsLvDraftWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
