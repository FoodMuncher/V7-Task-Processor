defmodule V7TaskProcessor.EventProcessing.Wrapper do
  @moduledoc """
  Simple implementation of the Event Processing behaviour.
  """
  @behaviour V7TaskProcessor.EventProcessing.Behaviour

  @minimum_wait Application.compile_env!(:v7_task_processor, [__MODULE__, :minimum_wait])
  @maximum_wait Application.compile_env!(:v7_task_processor, [__MODULE__, :maximum_wait])
  @failed_request_chance Application.compile_env!(:v7_task_processor, [__MODULE__, :failed_request_chance])

  #######################
  ## Callbacks

  @impl true
  def handle_event(_event) do
    wait()

    if success?() do
      :ok
    else
      :error
    end
  end

  #######################
  ## Internal Functions

  defp wait() do
    :rand.uniform(@maximum_wait - @minimum_wait) + @minimum_wait
    |> :timer.sleep()
  end

  defp success?() do
    :rand.uniform() > @failed_request_chance
  end
end
