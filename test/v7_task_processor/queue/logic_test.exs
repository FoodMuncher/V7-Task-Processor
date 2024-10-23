defmodule V7TaskProcessor.Queue.LogicTest do
  use ExUnit.Case

  import Mox

  require Logger
  alias V7TaskProcessor.Event
  alias V7TaskProcessor.Queue.{Logic, Priority, DeadLetter}
  alias V7TaskProcessor.Queue.Server, as: Queue

  #######################
  ## Setup

  setup :set_mox_global
  setup :verify_on_exit!

  #######################
  ## Tests

  test "startup/1 test" do
    assert %Queue{inactive_workers: workers} = Logic.startup(%Queue{})

    assert 3 == length(workers)
  end

  describe "add_event/2 tests -" do
    test "No inactive workers, expect to add event to internal queue" do
      event = %Event{priority: 1, correlation_id: "correlation_id"}
      assert %Queue{queues: queues} = Logic.add_event(event, %Queue{})

      assert {:ok, {internal_event, queues}} = Priority.fetch(queues)
      assert internal_event == event
      assert :error == Priority.fetch(queues)
    end

    test "There are inactive workers, expect to send the event to the worker" do
      event = %Event{priority: 1, correlation_id: "correlation_id"}
      assert state = %Queue{} = Logic.add_event(event, %Queue{inactive_workers: [self()]})

      assert :error == Priority.fetch(state.queues)
      assert [] == state.inactive_workers
      assert %{self() => event} == state.worker_events

      assert_receive {_, {:process_event, ^event}}
    end
  end

  describe "" do
    setup do
      event = %Event{
        priority: 3,
        correlation_id: "correlation_id",
        received_at: DateTime.utc_now()
      }

      state = %Queue{
        worker_events: %{self() => event}
      }

      %{state: state, event: event}
    end

    test "Previous request was succesful, no more events, expect :error returned and previous not to be requeud", ctx do
      assert {:error, state = %Queue{}} = Logic.next_event(true, self(), ctx.state)

      assert [self()] == state.inactive_workers
      assert %{} == state.worker_events
      assert :error == Priority.fetch(state.queues)
    end

    test "Previous request was succesful, we have queued events, expect event returned and previous not to be requeud", ctx do
      event = %Event{priority: 3, correlation_id: "different_id"}
      state = %Queue{ctx.state | queues: Priority.add(ctx.state.queues, event)}
      assert {{:ok, event}, state = %Queue{}} = Logic.next_event(true, self(), state)

      assert [] == state.inactive_workers
      assert %{self() => event} == state.worker_events
      assert :error == Priority.fetch(state.queues)
    end

    test "Previous request was unsuccesful, no queued events, expect previous event returned", ctx do
      assert {{:ok, event}, state = %Queue{}} = Logic.next_event(false, self(), ctx.state)

      assert event == %Event{ctx.event | retry: ctx.event.retry + 1}
      assert [] == state.inactive_workers
      assert %{self() => event} == state.worker_events
      assert :error == Priority.fetch(state.queues)
    end

    test "Previous request was unsuccesful with max retry, no queued events, expect :error returned", ctx do
      start_supervised!(DeadLetter)
      event = ctx.state.worker_events
      |> Map.fetch!(self())
      |> then(&(%Event{&1 | retry: 5}))

      state = %Queue{ctx.state | worker_events: Map.put(ctx.state.worker_events, self(), event)}
      assert {:error, state = %Queue{}} = Logic.next_event(false, self(), state)

      assert [self()] == state.inactive_workers
      assert %{} == state.worker_events
      assert :error == Priority.fetch(state.queues)

      assert [event] == DeadLetter.get()
    end

    test "Previous request was unsuccesful, lower priority, we have queued events, expect next event returned and previous queued", ctx do
      event = %Event{priority: 2, correlation_id: "different_id"}
      state = %Queue{ctx.state | queues: Priority.add(ctx.state.queues, event)}
      assert {{:ok, ^event}, state = %Queue{}} = Logic.next_event(false, self(), state)

      assert [] == state.inactive_workers
      assert %{self() => event} == state.worker_events
      assert {:ok, {previous_event, queues}} = Priority.fetch(state.queues)
      assert previous_event == %Event{ctx.event | retry: ctx.event.retry + 1}
      assert :error = Priority.fetch(queues)
    end

    test "Previous request was unsuccesful, higher priority, we have queued events, expect previous event returned", ctx do
      event = %Event{priority: 4, correlation_id: "different_id"}
      state = %Queue{ctx.state | queues: Priority.add(ctx.state.queues, event)}
      assert {{:ok, next_event}, state = %Queue{}} = Logic.next_event(false, self(), state)

      assert next_event == %Event{ctx.event | retry: ctx.event.retry + 1}

      previous_event = %Event{ctx.event | retry: ctx.event.retry + 1}
      assert next_event == previous_event
      assert [] == state.inactive_workers
      assert %{self() => previous_event} == state.worker_events
      assert {:ok, {^event, queues}} = Priority.fetch(state.queues)
      assert :error = Priority.fetch(queues)
    end

    test "Previous request can't be found", ctx do
      state = %Queue{ctx.state | worker_events: Map.delete(ctx.state.worker_events, self())}

      assert {:error, state = %Queue{}} = Logic.next_event(false, self(), state)

      assert [self()] == state.inactive_workers
      assert %{} == state.worker_events
      assert :error = Priority.fetch(state.queues)
    end
  end

  describe "handle_worker_down/3 -" do

    test "Worker had work and events in the queue, expect to be requeued and send next work" do
      pid = self()
      crashed_event = %Event{priority: 1, correlation_id: "crashed_event", received_at: DateTime.utc_now()}
      next_event = %Event{priority: 1, correlation_id: "next_event", received_at: DateTime.utc_now()}
      state = %Queue{
        worker_events: %{pid => crashed_event},
        queues: Priority.add(Priority.new(), next_event)
      }

      Mox.expect(V7TaskProcessor.EventProcessing.Mock, :handle_event, fn(event) ->
        assert event == next_event
        send(pid, :handled_request)
        :ok
      end)

      assert state = %Queue{} = Logic.handle_worker_down(pid, "crashed", state)

      crashed_event = %Event{crashed_event | retry: crashed_event.retry + 1}
      assert {:ok, {^crashed_event, queues}} = Priority.fetch(state.queues)
      assert :error == Priority.fetch(queues)
      assert [] == state.inactive_workers

      assert_receive :handled_request
    end

    test "Worker had work and no events in the queue, expect to be sent crashed work" do
      pid = self()
      crashed_event = %Event{priority: 1, correlation_id: "crashed_event", received_at: DateTime.utc_now()}
      state = %Queue{
        worker_events: %{pid => crashed_event}
      }

      Mox.expect(V7TaskProcessor.EventProcessing.Mock, :handle_event, fn(event) ->
        assert event == %Event{crashed_event | retry: crashed_event.retry + 1}
        send(pid, :handled_request)
        :ok
      end)

      assert state = %Queue{} = Logic.handle_worker_down(pid, "crashed", state)

      assert :error == Priority.fetch(state.queues)
      assert [] == state.inactive_workers

      assert_receive :handled_request
    end

    test "Worker had no work and events in the queue, expect to send crashed event" do
      pid = self()
      next_event = %Event{priority: 1, correlation_id: "next_event", received_at: DateTime.utc_now()}
      state = %Queue{
        queues: Priority.add(Priority.new(), next_event)
      }

      Mox.expect(V7TaskProcessor.EventProcessing.Mock, :handle_event, fn(event) ->
        assert event == next_event
        send(pid, :handled_request)
        :ok
      end)

      assert state = %Queue{} = Logic.handle_worker_down(pid, "crashed", state)

      assert :error == Priority.fetch(state.queues)
      assert [] == state.inactive_workers

      assert_receive :handled_request
    end

    test "Worker had no work and no events in the queue, expect worker to be started, but inactive" do
      pid = self()
      state = %Queue{}

      assert state = %Queue{} = Logic.handle_worker_down(pid, "crashed", state)

      assert :error == Priority.fetch(state.queues)
      assert [pid] = state.inactive_workers
      assert %{} == state.worker_events
      assert is_pid(pid)
    end
  end
end
