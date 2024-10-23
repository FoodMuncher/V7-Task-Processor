defmodule V7TaskProcessor.Worker.LogicTest do
  use ExUnit.Case

  import Mox

  alias V7TaskProcessor.Event
  alias V7TaskProcessor.Worker.Logic
  alias V7TaskProcessor.Queue.Server, as: Queue

  #######################
  ## Setup

  setup_all do
    # Update the worker count to zero, so we cna add ot the queue, without the events beng processed.
    config = Application.get_env(:v7_task_processor, V7TaskProcessor.Queue.Logic)

    Application.put_env(:v7_task_processor, V7TaskProcessor.Queue.Logic, Keyword.put(config, :worker_count, 0))

    on_exit(fn -> Application.put_env(:v7_task_processor, V7TaskProcessor.Queue.Logic, config) end)
    :ok
  end

  setup :set_mox_global
  setup :verify_on_exit!
  setup do
    start_supervised!(Queue)
    :ok
  end

  #######################
  ## Tests

  describe "handle_event/3 -" do
    test "Event Succesful, Queue has no events, expect worker to stop after one event" do
      current_event = %Event{priority: 1, correlation_id: "current", received_at: DateTime.utc_now()}
      expect(V7TaskProcessor.EventProcessing.Mock, :handle_event, fn(event) ->
        assert event == current_event
        :ok
      end)

      assert :ok == Logic.handle_event(current_event)
    end

    test "Event Unsuccesful, Queue has no events, expect worker to stop after one event, and event to be sent over" do
      current_event = %Event{priority: 1, correlation_id: "current", received_at: DateTime.utc_now()}
      expect(V7TaskProcessor.EventProcessing.Mock, :handle_event, fn(event) ->
        assert event == current_event
        :error
      end)

      assert :ok == Logic.handle_event(current_event)
    end

    test "Event Succesful, Queue has events, expect worker to process all events" do
      current_event = %Event{priority: 1, correlation_id: "current", received_at: DateTime.utc_now()}
      event1 = %Event{priority: 1, correlation_id: "event1", received_at: DateTime.utc_now()}
      event2 = %Event{priority: 1, correlation_id: "event2", received_at: DateTime.utc_now()}
      event3 = %Event{priority: 1, correlation_id: "event3", received_at: DateTime.utc_now()}

      Queue.add_event(event1)
      Queue.add_event(event2)
      Queue.add_event(event3)


      expect(V7TaskProcessor.EventProcessing.Mock, :handle_event, fn(event) ->
        assert event == current_event
        :ok
      end)
      expect(V7TaskProcessor.EventProcessing.Mock, :handle_event, fn(event) ->
        assert event == event1
        :ok
      end)
      expect(V7TaskProcessor.EventProcessing.Mock, :handle_event, fn(event) ->
        assert event == event2
        :ok
      end)
      expect(V7TaskProcessor.EventProcessing.Mock, :handle_event, fn(event) ->
        assert event == event3
        :ok
      end)

      assert :ok == Logic.handle_event(current_event)
    end
  end
end
