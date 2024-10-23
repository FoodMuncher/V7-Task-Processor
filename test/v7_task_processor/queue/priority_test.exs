defmodule V7TaskProcessor.Queue.PriorityTest do
  use ExUnit.Case, async: true

  alias V7TaskProcessor.Event
  alias V7TaskProcessor.Queue.Priority

  #######################
  ## Tests

  test "new/0 test" do
    assert {[], %{}} == Priority.new()
  end

  test "add/2 test" do
    pqueue = Priority.new()

    event1 = %Event{correlation_id: 1, priority: 4}
    queue4 = :queue.from_list([event1])
    pqueue = Priority.add(pqueue, event1)
    assert {[4], %{4 => queue4}} == pqueue

    event2 = %Event{correlation_id: 2, priority: 2}
    queue2 = :queue.from_list([event2])
    pqueue = Priority.add(pqueue, event2)
    assert {[2, 4], %{2 => queue2, 4 => queue4}} == pqueue

    event3 = %Event{correlation_id: 3, priority: 5}
    queue5 = :queue.from_list([event3])
    pqueue = Priority.add(pqueue, event3)
    assert {[2, 4, 5], %{2 => queue2, 4 => queue4, 5 => queue5}} == pqueue

    event4 = %Event{correlation_id: 4, priority: 4}
    queue4 = :queue.in(event4, queue4)
    pqueue = Priority.add(pqueue, event4)
    assert {[2, 4, 5], %{2 => queue2, 4 => queue4, 5 => queue5}} == pqueue

    event5 = %Event{correlation_id: 5, priority: 2}
    queue2 = :queue.in(event5, queue2)
    pqueue = Priority.add(pqueue, event5)
    assert {[2, 4, 5], %{2 => queue2, 4 => queue4, 5 => queue5}} == pqueue
  end

  test "fetch/1 test" do
    pqueue = Priority.new()

    assert :error == Priority.fetch(pqueue)

    event1 = %Event{correlation_id: 1, priority: 4}
    event2 = %Event{correlation_id: 2, priority: 5}
    event3 = %Event{correlation_id: 3, priority: 2}
    event4 = %Event{correlation_id: 4, priority: 4}

    pqueue = pqueue
    |> Priority.add(event1)
    |> Priority.add(event2)
    |> Priority.add(event3)
    |> Priority.add(event4)

    assert {:ok, {event, pqueue}} = Priority.fetch(pqueue)
    assert event == event3

    assert {:ok, {event, pqueue}} = Priority.fetch(pqueue)
    assert event == event1

    assert {:ok, {event, pqueue}} = Priority.fetch(pqueue)
    assert event == event4

    assert {:ok, {event, pqueue}} = Priority.fetch(pqueue)
    assert event == event2

    assert :error = Priority.fetch(pqueue)
  end
end
