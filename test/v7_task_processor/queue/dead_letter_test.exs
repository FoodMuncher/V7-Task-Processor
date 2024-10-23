defmodule V7TaskProcessor.Queue.DeadLetterTest do
  use ExUnit.Case, async: true

  alias V7TaskProcessor.Event
  alias V7TaskProcessor.Queue.DeadLetter

  #######################
  ## Setup

  setup do
    start_supervised!(DeadLetter)
    :ok
  end

  #######################
  ## Tests

  test "Check Dead Letter initial state, expect empty list" do
    assert DeadLetter.get() == []
  end

  test "Check events can be added to the queue" do
    event1 = %Event{correlation_id: 1}
    DeadLetter.add(event1)
    assert [event1] == DeadLetter.get()

    event2 = %Event{correlation_id: 2}
    DeadLetter.add(event2)
    assert [event2, event1] == DeadLetter.get()

    event3 = %Event{correlation_id: 3}
    DeadLetter.add(event3)
    assert [event3, event2, event1] == DeadLetter.get()

    event4 = %Event{correlation_id: 4}
    DeadLetter.add(event4)
    assert [event4, event3, event2, event1] == DeadLetter.get()
  end
end
