defmodule V7TaskProcessor.EventTest do
  use ExUnit.Case, async: true

  alias V7TaskProcessor.Event

  describe "parse/3 tests -" do
    setup do
      params = %{
        "user_id"       => 123,
        "priority"      => 3,
        "event_data"    => "data",
        "event_type_id" => 6
      }

      %{
        params: params,
        correlation_id: "correlation_id",
        datetime: DateTime.utc_now()
      }
    end

    test "Succesfully parse, expect Event to be returned", ctx do
      event = %Event{
        user_id:        123,
        priority:       3,
        event_data:     "data" ,
        received_at:    ctx.datetime,
        event_type_id:  6,
        correlation_id: ctx.correlation_id,
        retry:          0
      }

      assert {:ok, event} == Event.parse(ctx.params, ctx.correlation_id, ctx.datetime)
    end

    test "Missing , expect :error return", ctx do
      params = Map.delete(ctx.params, "user_id")
      assert {:error, _} = Event.parse(params, ctx.correlation_id, ctx.datetime)
    end

    test "Missing priority, expect :error return", ctx do
      params = Map.delete(ctx.params, "priority")
      assert {:error, _} = Event.parse(params, ctx.correlation_id, ctx.datetime)
    end

    test "Missing event_data, expect :error return", ctx do
      params = Map.delete(ctx.params, "event_data")
      assert {:error, _} = Event.parse(params, ctx.correlation_id, ctx.datetime)
    end

    test "Missing event_type_id, expect :error return", ctx do
      params = Map.delete(ctx.params, "event_type_id")
      assert {:error, _} = Event.parse(params, ctx.correlation_id, ctx.datetime)
    end

    test "user_id not an integer, expect :error return", ctx do
      params = Map.put(ctx.params, "user_id", "not_integer")
      assert {:error, _} = Event.parse(params, ctx.correlation_id, ctx.datetime)
    end

    test "priority not an integer, expect :error return", ctx do
      params = Map.put(ctx.params, "priority", "not_integer")
      assert {:error, _} = Event.parse(params, ctx.correlation_id, ctx.datetime)
    end

    test "event_type_id not an integer, expect :error return", ctx do
      params = Map.put(ctx.params, "event_type_id", "not_integer")
      assert {:error, _} = Event.parse(params, ctx.correlation_id, ctx.datetime)
    end

  end

  describe "retry/1 tests -" do
    setup do
      event = %Event{
        user_id:        123,
        priority:       4,
        event_data:     "data",
        received_at:    DateTime.utc_now(),
        event_type_id:  5,
        correlation_id: "correlation_id"
      }

      %{event: event}
    end

    test "0 initial retries, expect to be updated to 1", ctx do
      assert {:ok, %Event{ctx.event | retry: 1}} == Event.retry(ctx.event)
    end

    test "1 initial retries, expect to be updated to 2", ctx do
      event = %Event{ctx.event | retry: 1}
      assert {:ok, %Event{ctx.event | retry: 2}} == Event.retry(event)
    end

    test "2 initial retries, expect to be updated to 3", ctx do
      event = %Event{ctx.event | retry: 2}
      assert {:ok, %Event{ctx.event | retry: 3}} == Event.retry(event)
    end

    test "3 initial retries, expect to be updated to 4", ctx do
      event = %Event{ctx.event | retry: 3}
      assert {:ok, %Event{ctx.event | retry: 4}} == Event.retry(event)
    end

    test "4 initial retries, expect to be updated to 5", ctx do
      event = %Event{ctx.event | retry: 4}
      assert {:ok, %Event{ctx.event | retry: 5}} == Event.retry(event)
    end

    test "5 initial retries, expect :error to be returned", ctx do
      event = %Event{ctx.event | retry: 5}
      assert :error == Event.retry(event)
    end
  end

  test "latency/1 test" do
    datetime = DateTime.add(DateTime.utc_now(), -10)
    assert %{latency: latency} = Event.latency(%Event{received_at: datetime})
    assert latency > 0
  end

  test "metric_metadata/1 test" do
    correlation_id = "correlation_id"
    assert %{correlation_id: correlation_id} == Event.metric_metadata(%Event{correlation_id: correlation_id})
  end
end
