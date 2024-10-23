defmodule V7TaskProcessor.Event do
  @moduledoc """
  Module to house the Event struct and it's utility functions.
  """

  @maximum_retry Application.compile_env!(:v7_task_processor, [__MODULE__, :maximum_retry])

  #######################
  ## Struct

  @type t() :: %__MODULE__{
    user_id:        integer(),
    priority:       integer(),
    event_data:     term(),
    received_at:    DateTime.t(),
    event_type_id:  integer(),
    correlation_id: String.t(),
    retry:          integer()
  }

  defstruct [
    :user_id,
    :priority,
    :event_data,
    :received_at,
    :event_type_id,
    :correlation_id,
    retry: 0
  ]

  #######################
  ## Exported Functions

  @doc """
  Parses the incoming, returning an Event struct.
  If any of the fields are missing or the incorrect type,
  the parsing function will fail and return the fail reason.
  """
  @spec parse(map(), String.t(), DateTime.t()) :: {:ok, t()} | {:error, reason :: String.t()}
  def parse(params, correlation_id, received_at) do
    with {:ok, user_id} <- parse_integer(params, "user_id"),
         {:ok, priority} <- parse_integer(params, "priority"),
         {:ok, event_data} <- parse_required(params, "event_data"),
         {:ok, event_type_id} <- parse_integer(params, "event_type_id")
    do
      {:ok, %__MODULE__{
        user_id:        user_id,
        priority:       priority,
        event_data:     event_data,
        received_at:    received_at,
        event_type_id:  event_type_id,
        correlation_id: correlation_id
      }}
    end
  end

  @doc """
    Bumps the retry counter of the Event. If it hits the maximum number of retries, `:error` is returned.
  """
  @spec retry(t()) :: {:ok, t()} | :error
  def retry(%__MODULE__{retry: @maximum_retry}), do: :error
  def retry(event = %__MODULE__{}) do
    {:ok, %__MODULE__{event | retry: event.retry + 1}}
  end

  @doc """
  Returns the milliseconds since we received the event.
  """
  @spec latency(t()) :: %{latency: integer()}
  def latency(event = %__MODULE__{}) do
    %{latency: DateTime.diff(DateTime.utc_now(), event.received_at, :millisecond)}
  end

  @doc """
  Converts the Event to a metric metadata map
  """
  @spec metric_metadata(t()) :: %{correlation_id: String.t()}
  def metric_metadata(event = %__MODULE__{}) do
    %{correlation_id: event.correlation_id}
  end

  #######################
  ## Internal Functions

  defp parse_integer(params, field) do
    case Map.fetch(params, field) do
      {:ok, integer} when is_integer(integer) -> {:ok, integer}
      {:ok, non_integer} -> {:error, "Expected #{field} to be an integer, but received #{inspect non_integer}"}
      :error -> {:error, "missing required field: #{field}"}
    end
  end

  defp parse_required(params, field) do
    with :error <- Map.fetch(params, field) do
      {:error, "missing required field: #{field}"}
    end
  end

end
