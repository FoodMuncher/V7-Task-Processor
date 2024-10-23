import Config

config :v7_task_processor, V7TaskProcessor.Queue.Logic,
  worker_count: 3

config :v7_task_processor, V7TaskProcessor.Worker.Logic,
  event_processor: V7TaskProcessor.EventProcessing.Mock

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :v7_task_processor, V7TaskProcessorWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "h0Z6ZMIzpTOo/1fwRxyFe4D1ctJk9XLxUHo5xsK1mFhD6au6a+dOB63d+8eYFZkO",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
