defmodule V7TaskProcessor.Queue.DeadLetter do
  @moduledoc """
  Simple implementation of the Dead Letter queue.
  """
  use Agent

  alias V7TaskProcessor.Event
  alias V7TaskProcessor.Queue.Server, as: Queue

  @empty_queue []

  #######################
  ## Exported Functions

  @doc """
  Starts up the dead letter queue.
  """
  @spec start_link(term()) :: Agent.on_start()
  def start_link(_args) do
    Agent.start_link(fn -> @empty_queue end, name: __MODULE__)
  end

  @doc """
  Adds an event to the dead leter queue.
  """
  @spec add(Event.t()) :: :ok
  def add(event) do
    Agent.update(__MODULE__, &([event | &1]))
  end

  @doc """
  Empties all the events out of the dead letter queue and adds them back into the event queue.

  As this is a simple implementation of the dead letter queue, I opted to just use Enum.each/2.
  If this was a more robust implementation we might want to use something like
  Task.async_stream/5 or even a custom written solution.
  """
  @spec requeue() :: :ok
  def requeue() do
    Agent.get_and_update(__MODULE__, &({&1, @empty_queue}))
    |> Enum.each(&(Queue.add_event(&1)))
  end

  @doc """
  Returns all the events currently in the dead letter queue.
  """
  @spec get() :: [Event.t()]
  def get() do
    Agent.get(__MODULE__, &(&1))
  end
end
