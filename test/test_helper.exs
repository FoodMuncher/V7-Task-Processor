# Capture logs, so we only display logs when a test fails.
ExUnit.start(capture_log: true)

# Mocks:
Mox.defmock(V7TaskProcessor.EventProcessing.Mock, for: V7TaskProcessor.EventProcessing.Behaviour)
