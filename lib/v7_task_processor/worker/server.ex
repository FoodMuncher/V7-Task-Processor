defmodule V7TaskProcessor.Worker.Server do
  use GenServer

  require Logger

  alias V7TaskProcessor.Event
  alias V7TaskProcessor.Worker.Logic

  #######################
  ## Exported Functions

  @doc """
  Starts the Worker GenServer.

  Since our workers have no start up functionality, theoretically, they should always start up,
  so I have used the bang version.
  If the workers had more functionality on start up, I would implement better handling around this,
  such as a back off retry mechanism to keep attempting to start the workers.
  """
  @spec start_link!() :: pid()
  def start_link!() do
    case GenServer.start_link(__MODULE__, []) do
      {:ok, pid} ->
        pid

      {:error, reason} ->
        throw({:start_up_error, "Failed to start up Worker, Reason: #{inspect reason}"})
    end
  end

  @doc """
  Gives the worker a new event to process. The worker will now
  continue to check the queue until there's no more work, where it will
  stopping checking the queue and wait for more work to be sent to it via this function.
  """
  @spec process_event(pid(), Event.t()) :: :ok
  def process_event(worker_pid, event) do
    GenServer.cast(worker_pid, {:process_event, event})
  end

  #######################
  ## Callback Functions

  @impl true
  def init(_args) do
    Logger.info("Worker Started for PID: #{inspect self()}")
    {:ok, nil}
  end

  @impl true
  def handle_cast({:process_event, event}, state) do
    Logic.handle_event(event)
    {:noreply, state}
  end

end
