defmodule V7TaskProcessor.Queue.Server do
  @moduledoc """
  The Genserver module for the Queue.
  The Queue will start a configurable number of workers, then wait too receive an event.
  It will route the event to one of the workers, if all workers are busy processing
  requests, it will add the event to it's internal queue.
  """
  use GenServer

  require Logger

  alias V7TaskProcessor.Event
  alias V7TaskProcessor.Queue.{Logic, Priority}

  @type state() :: %__MODULE__{
    worker_events:        %{worker_pid :: pid() => event :: Event.t() | nil},
    inactive_workers:     [worker_pid :: pid()],
    high_priortity_queue: :queue.queue(event :: Event.t()),
    queues:               Priority.t()
  }

  defstruct [
    worker_events:        %{},
    inactive_workers:     [],
    high_priortity_queue: :queue.new(),
    queues:               Priority.new()
  ]

  #######################
  ## Exported Functions

  @doc """
  Starts the queue server.
  """
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc """
  Adds the event to the queue, where it will be processed by a worker.

  I decided to use `call` here, so that the calling process could be certain that the event had reached the queue.
  This means our `call` could timeout in the event of a very long message queue, so I've set the timeout to be infiity to combat this.
  """
  @spec add_event(Event.t()) :: :ok
  def add_event(event) do
    GenServer.call(__MODULE__, {:add_event, event}, :infinity)
  end

  @doc """
  This function will be called by a worker.
  It will return the next event in the queue, if one exists.
  Additionally, this function takes a boolean as an arguement,
  the boolean describes whehter the previous event the worker processed was succesful or not.
  If it wasn't succesful, the previous event will be requeued.
  """
  @spec next_event(boolean()) :: {:ok, Event.t()} | :error
  def next_event(previous_succeeded?) do
    GenServer.call(__MODULE__, {:next_event, previous_succeeded?})
  end

  #######################
  ## Callback Functions

  @impl true
  def init(_init_arg) do
    Logger.info("Queue starting up...")
    # We trap exits because in the event of a worker crash, the queue will be notified.
    # It can then restart the worker, and re-assign the event it was processsing.
    Process.flag(:trap_exit, true)
    {:ok, %__MODULE__{}, {:continue, nil}}
  end

  @impl true
  def handle_continue(nil, state = %__MODULE__{}) do
    {:noreply, Logic.startup(state)}
  end

  @impl true
  def handle_call({:add_event, event = %Event{}}, _from, state = %__MODULE__{}) do
    :telemetry.execute([:v7_task_processor, :enter_queue], Event.latency(event), Event.metric_metadata(event))
    {:reply, :ok, Logic.add_event(event, state)}
  end
  def handle_call({:next_event, previous_succeeded?}, {worker_pid, _tag}, state = %__MODULE__{}) do
    {reply, state} = Logic.next_event(previous_succeeded?, worker_pid, state)
    {:reply, reply, state}
  end

  @impl true
  def handle_info({:EXIT, worker_pid, reason}, state = %__MODULE__{}) do
    {:noreply, Logic.handle_worker_down(worker_pid, reason, state)}
  end

end
