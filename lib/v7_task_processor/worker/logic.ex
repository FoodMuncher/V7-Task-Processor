defmodule V7TaskProcessor.Worker.Logic do
  @moduledoc """
  Contains the logic for the Worker Server.

  Split out from the server to allow better testing of the functionality.
  """
  require Logger

  alias V7TaskProcessor.Event
  alias V7TaskProcessor.Queue.Server, as: Queue

  @event_processor Application.compile_env!(:v7_task_processor, [__MODULE__, :event_processor])

  #######################
  ## Exported Functions

  @doc """
  Process the given event. Once processed, we call the Queue
  to get the next event and notify it if the current event was succesful or not.

  * If the Queue returns another event, we process that and continue the cycle.
  * If the Queue doesn't return another event, the worker stops attempting
    to get events, and instead waits for the Queue to notify it of a new event.
  """
  @spec handle_event(Event.t()) :: :ok
  def handle_event(event = %Event{}) do
    Logger.info("Worker processing event: #{inspect event}", correlation_id: event.correlation_id)
    :telemetry.execute([:v7_task_processor, :worker_received_request], Event.latency(event), Event.metric_metadata(event))
    case @event_processor.handle_event(event) do
      :ok ->
        :telemetry.execute([:v7_task_processor, :event_success], Event.latency(event), Event.metric_metadata(event))
        Logger.info("Worker: #{inspect self()} successfully handle: #{inspect event}", correlation_id: event.correlation_id)
        handle_next_event(true)

      :error ->
        :telemetry.execute([:v7_task_processor, :event_failure], Event.latency(event), Event.metric_metadata(event))
        Logger.warning("Worker: #{inspect self()} failed to handle: #{inspect event}", correlation_id: event.correlation_id)
        handle_next_event(false)
    end
  end

  #######################
  ## Internal Functions

  defp handle_next_event(succeeded?) do
    case Queue.next_event(succeeded?) do
      {:ok, event} ->
        handle_event(event)

      :error ->
        Logger.info("No more work, worker: #{inspect self()} going into standby.")
        :ok
    end
  end
end
