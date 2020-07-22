defmodule CbreportWeb.PageController do
  use CbreportWeb, :controller

  def index(conn, _params) do
    columns = request_workflows()
    active_cards = request_stories(columns)
    create_json(active_cards, columns)

    render(conn, "index.html")
  end

  defp request_stories(columns) do
    if %HTTPoison.Response{status_code: 200, body: body} = get_stories() do
      columns_ids = Enum.map(columns, fn x -> x["id"] end)

      Enum.filter(Jason.decode!(body), fn x ->
        x["workflow_state_id"] in columns_ids
      end)
    else
      nil
    end
  end

  defp request_workflows() do
    if %HTTPoison.Response{status_code: 200, body: body} = get_workflows() do
      body
      |> Jason.decode!()
      |> Enum.filter(fn x -> x["project_ids"] == [42562] end)
      |> List.first()
      |> Map.get("states")
      |> Enum.filter(fn x -> x["type"] == "started" end)
    else
      nil
    end
  end

  defp get_stories do
    url =
      "https://api.clubhouse.io/api/v2/projects/42562/stories?token=5f162a4d-f8f8-495b-ae95-83832b79dc24"

    HTTPoison.get!(url)
  end

  defp get_workflows do
    url = "https://api.clubhouse.io/api/v3/workflows?token=5f162a4d-f8f8-495b-ae95-83832b79dc24"

    HTTPoison.get!(url)
  end

  defp create_json(active_cards, columns) do
    columns_parsed = Enum.map(columns, fn x -> %{id: x["id"], name: x["name"]} end)

    Enum.map(active_cards, fn x ->
      %{
        updated_at: x["moved_at"],
        name: x["name"],
        story_type: x["story_type"],
        app_url: x["app_url"],
        column: find_column(x["workflow_state_id"], columns_parsed),
        duration: date_moved(x["moved_at"])
      }
    end)
  end

  defp date_moved(moved_at) do
    {:ok, dt} = Elixir.Timex.Parse.DateTime.Parser.parse(moved_at, "{ISO:Extended:Z}")

    Timex.diff(Timex.now(), dt, :days)
  end

  defp find_column(workflow_state_id, columns) do
    Enum.find(columns, fn x -> workflow_state_id == x.id end).name
  end
end
