defmodule V7TaskProcessorWeb.ErrorJSONTest do
  use V7TaskProcessorWeb.ConnCase, async: true

  test "renders 404" do
    assert V7TaskProcessorWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert V7TaskProcessorWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
