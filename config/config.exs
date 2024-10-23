# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :v7_task_processor,
  env: config_env()

config :v7_task_processor, V7TaskProcessor.Event,
  maximum_retry: 5

config :v7_task_processor, V7TaskProcessor.Queue.Logic,
  worker_count: 5

config :v7_task_processor, V7TaskProcessor.Worker.Logic,
  event_processor: V7TaskProcessor.EventProcessing.Wrapper

config :v7_task_processor, V7TaskProcessor.EventProcessing.Wrapper,
  minimum_wait: 250, # 1/4 of a second
  maximum_wait: 2000, # 2 seconds
  failed_request_chance: 0.1 # 10% chance

# Configures the endpoint
config :v7_task_processor, V7TaskProcessorWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [json: V7TaskProcessorWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: V7TaskProcessor.PubSub,
  live_view: [signing_salt: "cJyk/avp"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
