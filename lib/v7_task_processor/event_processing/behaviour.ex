defmodule V7TaskProcessor.EventProcessing.Behaviour do
  @moduledoc """
  Module to house the behaviour for event processing.

  I've added this so that I can utilise Mox in the tests, but this behaviour
  could also be useful in the event we want different event processing functionality based on event type.
  """

  alias V7TaskProcessor.Event

  @callback handle_event(event :: Event.t()) :: :ok | :error
end
