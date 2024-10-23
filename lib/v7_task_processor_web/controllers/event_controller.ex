defmodule V7TaskProcessorWeb.EventController do
  @moduledoc """
  The controller callback module for the endpoint: "/event/v1".
  """
  use V7TaskProcessorWeb, :controller

  require Logger

  alias V7TaskProcessor.Event
  alias V7TaskProcessor.Queue.Server, as: Queue

  #######################
  ## Router Callback

  @doc """
  Parses the event, if it can be successfully parsed, it will then add it to the Queue.
  If it can't be parsed, it will return a 400. along with extra information on why the request failed.
  """
  @spec event(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def event(conn, params) do
    retrieved_at = DateTime.utc_now()
    correlation_id = get_correlation_id(conn)
    case Event.parse(params, correlation_id, retrieved_at) do
      {:ok, event} ->
        :telemetry.execute([:v7_task_processor, :parsed_request], Event.latency(event), Event.metric_metadata(event))
        Queue.add_event(event)
        text(conn, "Success")

      {:error, reason} ->
        :telemetry.execute([:v7_task_processor, :failed_parsed_request], %{count: 1}, %{correlation_id: correlation_id})
        Logger.error("Event Controller failed to parse request: #{inspect params}, as #{reason}", correlation_id: correlation_id)
        resp(conn, 400, "Failed to parse event, as #{reason}.")
    end
  end

  #######################
  ## Internal Functions

  # Using the bang version of fetch here, as if the correlation id is missing something is fundamentally wrong with the code.
  # The Plug wihtin the Router, means we should always have a request id.
  defp get_correlation_id(conn) do
    conn
    |> Map.fetch!(:assigns)
    |> Map.fetch!(:correlation_id)
  end

end
