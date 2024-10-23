defmodule V7TaskProcessor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @environment Application.compile_env!(:v7_task_processor, :env)

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      V7TaskProcessorWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: V7TaskProcessor.PubSub}
    ]
    ++
    environment_start_up(@environment)
    ++
    [
      # Start the Endpoint (http/https)
      V7TaskProcessorWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: V7TaskProcessor.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    V7TaskProcessorWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp environment_start_up(:test), do: []
  defp environment_start_up(_env) do
    [
      # Start the Dead Letter Queue Agent
      V7TaskProcessor.Queue.DeadLetter,
      # Start the Queue GenServer
      V7TaskProcessor.Queue.Server
    ]
  end
end
