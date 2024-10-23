defmodule V7TaskProcessor.Queue.Priority do
  @moduledoc """
  Module to house the logic behind the priority queue data type.
  This queue will return the oldest event, with the highest priority (lower the number higher the priority).
  It does this by keep track of all the priorities in an ordered set, and grouping all events by priority in a map.
  I will check the ordered set for the highest priority (lowest number), then fetch from the queue from the map,
  returning the next item in that queue.

  The logic for this data type has been split out into its own module to help with
  testing the functionality of the priority queue.
  As well as, allowing for new implementations of the priority queue to be easily
  swapped out. i.e. using the erlang library gb_tree.
  """
  alias V7TaskProcessor.Event

  @type t() :: {:ordsets.ordset(integer), map()}

  @doc """
  Return an empty priortity queue.
  """
  @spec new() :: t()
  def new(), do: {:ordsets.new(), %{}}

  @doc """
  Returns the next event from the queue, taking priority of the event into consideration.
  """
  @spec fetch(t()) :: {:ok, {Event.t(), t()}} | :error
  def fetch({[], _}), do: :error
  def fetch({[priority | tail] = priorities, queues}) do
    {{:value, event}, queue} = queues
    |> Map.get(priority)
    |> :queue.out()

    pqueue = if :queue.is_empty(queue) do
      # Queue is empty, remove the priority from the queues map and the priorty list.
      {tail, Map.delete(queues, priority)}
    else
      {priorities, Map.put(queues, priority, queue)}
    end

    {:ok, {event, pqueue}}
  end

  @doc """
  Adds the event into the priority queue.
  """
  @spec add(t(), Event.t()) :: t()
  def add({priorities, queues}, event = %Event{}) do
    queue = case Map.fetch(queues, event.priority) do
      {:ok, queue} -> queue
      :error -> :queue.new()
    end

    {:ordsets.add_element(event.priority, priorities), Map.put(queues, event.priority, :queue.in(event, queue))}
  end
end
