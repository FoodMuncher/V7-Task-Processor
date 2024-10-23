defmodule V7TaskProcessor.Queue.Logic do
  @moduledoc """
  Module for all the Queue GenServer functionality.
  It has been split out into it's own module to allow for easier testing.
  """
  require Logger

  alias V7TaskProcessor.Event
  alias V7TaskProcessor.Queue.{Priority, DeadLetter}
  alias V7TaskProcessor.Queue.Server, as: Queue
  alias V7TaskProcessor.Worker.Server, as: Worker

  #######################
  ## Exported Functions

  @doc """
  Starts up the configured number of workers.
  The Queue controls the start up of the workers, so it can have
  control over when the workers crash and can restart when needed.
  """
  @spec startup(Queue.t()) :: Queue.t()
  def startup(state = %Queue{}) do
    worker_count = Application.get_env(:v7_task_processor, __MODULE__)[:worker_count]
    # Since our workers have no start up functionality, theoretically, they should always start up,
    # so I have used the bang version.
    # If the workers had more functionality on start up, I would implement better handling around this,
    # such as a back off retry mechanism to keep attempting to start the workers.
    workers = if worker_count > 0 do
      for _i <- 1..worker_count, do: Worker.start_link!()
    else
      []
    end

    %Queue{state | inactive_workers: workers}
  end

  @doc """
  Adds the event to the queue if all workers are currently processing other events.
  If we have inactive workers, it will send the event to it.
  """
  @spec add_event(Event.t(), Queue.t()) :: Queue.t()
  def add_event(event = %Event{}, state = %Queue{inactive_workers: []}) do
    Logger.info("Queue adding event: #{inspect event} to state", correlation_id: event.correlation_id)
    %Queue{state | queues: Priority.add(state.queues, event)}
  end
  def add_event(event = %Event{}, state = %Queue{inactive_workers: [worker_pid | workers_tail]}) do
    Logger.info("Queue sending event: #{inspect event}to worker", correlation_id: event.correlation_id)
    Worker.process_event(worker_pid, event)

    %Queue{state |
      worker_events: Map.put(state.worker_events, worker_pid, event),
      inactive_workers: workers_tail
    }
  end

  @doc """
  Returns the next event in the queue to the calling worker, if there is any work.
  It also takes a boolean arguement, which describes if the previous event was succesful.
  If it was succesful, nothing extra is done.
  If it was unsuccesful, it adds the event to the back of the queue, or sends it to the
  dead letter queue if it has hit the maximum number of retries.
  """
  @spec next_event(boolean(), pid(), Queue.t()) :: {{:ok, Event.t()} | :error, Queue.t()}
  def next_event(true, worker_pid, state = %Queue{}) do
    do_next_event(state, worker_pid)
  end
  def next_event(false, worker_pid, state = %Queue{}) do
    # Add the worker's previous event to the back of the queue.
    case Map.fetch(state.worker_events, worker_pid) do
      {:ok, event} ->
        requeue_event(state, event)

      :error ->
        Logger.error("Attempted to re-queue work for worker: #{inspect worker_pid}, but failed to find event in the queue state.")
        state
    end
    |> do_next_event(worker_pid)
  end

  @doc """
  Updates the state to remove the dead worker, as well as, requeuing its work.
  It will start a new worker to replace the dead one.
  """
  @spec handle_worker_down(pid(), term(), Queue.state()) :: Queue.state()
  def handle_worker_down(worker_pid, reason, state = %Queue{}) do
    Logger.warning("Worker Queue received worker down message for #{inspect worker_pid} with reason: #{inspect reason}. Restarting worker...")

    # Update state to remove any mention of the old worker pid, and re-queue the worker's event.
    state = %Queue{} = case Map.pop(state.worker_events, worker_pid) do
      {event = %Event{}, worker_events} ->
        %Queue{state | worker_events: worker_events}
        |> requeue_event(event)

      {nil, _workers} ->
        %Queue{state | inactive_workers: remove_worker(state.inactive_workers, worker_pid)}
    end

    # Once again, here I'm using a bang version of the worker start up, since there is no start up functionality.
    # If the workers had more functionality on start up, I would implement better handling around this.
    worker_pid = Worker.start_link!()

    # Kick off the new worker to begin processing requests.
    case do_next_event(state, worker_pid) do
      {{:ok, event}, state} ->
        Worker.process_event(worker_pid, event)
        %Queue{state | worker_events: Map.put(state.worker_events, worker_pid, event)}

      {:error, state} ->
        state
    end
  end

  #######################
  ## Internal Functions

  defp do_next_event(state = %Queue{}, worker_pid) do
    case Priority.fetch(state.queues) do
      {:ok, {event = %Event{}, queues}} ->
        Logger.info("Queue returning event: #{inspect event} to worker", correlation_id: event.correlation_id)
        state = %Queue{state |
          queues: queues,
          worker_events: Map.put(state.worker_events, worker_pid, event)
        }
        {{:ok, event}, state}

      :error ->
        state = %Queue{state |
          worker_events: Map.delete(state.worker_events, worker_pid),
          inactive_workers: [worker_pid | state.inactive_workers]
        }
        {:error, state}
    end
  end

  defp requeue_event(state = %Queue{}, event) do
    case Event.retry(event) do
      {:ok, event} ->
        %Queue{state | queues: Priority.add(state.queues, event)}

        :error ->
          :telemetry.execute([:v7_task_processor, :dead_letter_queue], Event.latency(event), Event.metric_metadata(event))
          Logger.error("Event hit the maximum number of retries, being sent to the Dead Letter Queue.", correlation_id: event.correlation_id)
          DeadLetter.add(event)
          state
    end
  end

  defp remove_worker([], _worker_pid), do: []
  defp remove_worker([worker_pid | tail], worker_pid), do: tail
  defp remove_worker([pid | tail], worker_pid) do
    [pid | remove_worker(tail, worker_pid)]
  end

end
