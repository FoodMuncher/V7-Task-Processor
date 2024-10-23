defmodule V7TaskProcessorWeb.EventControllerTest do
  use V7TaskProcessorWeb.ConnCase
  require Logger

  import Mox

  alias V7TaskProcessor.Event
  alias V7TaskProcessor.Queue.Server, as: Queue

  #######################
  ## Setup

  setup :set_mox_global
  setup :verify_on_exit!

  #######################
  ## Tests

  describe "POST /event/v1 tests -" do
    test "Successfully add to queue, expect 200 return", ctx do
      start_supervised!(Queue)
      test_pid = self()

      expect(V7TaskProcessor.EventProcessing.Mock, :handle_event, fn(event = %Event{}) ->
        assert event.user_id == 123
        assert event.priority == 3
        assert event.event_data == "data"
        assert event.event_type_id == 6
        # Send message to the test, so we can verify the event was picked up and processed by a worker.
        send(test_pid, :received_event)
      end)

      body = %{
        user_id: 123,
        priority: 3,
        event_data: "data",
        event_type_id: 6
      }

      conn = post(ctx.conn, "/api/event/v1", body)

      assert text_response(conn, 200) == "Success"

      assert_receive :received_event
    end

    test "Fail to parse, expect 400 return", ctx do
      body = %{
        priority: 3,
        event_data: "data",
        event_type_id: 6
      }
      conn = post(ctx.conn, "/api/event/v1", body)

      assert response(conn, 400) =~ "Failed to parse event"
    end
  end
end
