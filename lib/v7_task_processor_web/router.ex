defmodule V7TaskProcessorWeb.Router do
  use V7TaskProcessorWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug Plug.RequestId, assign_as: :correlation_id
  end

  scope "/api", V7TaskProcessorWeb do
    pipe_through :api

    post "/event/v1", EventController, :event
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:v7_task_processor, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: V7TaskProcessorWeb.Telemetry
    end
  end
end
