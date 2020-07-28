defmodule CbreportWeb.PageController do
  use CbreportWeb, :controller

  def index(conn, %{"project_id" => project_id}) do
    project_id = String.to_integer(project_id)
    columns = request_workflows(project_id)

    active_cards = request_stories(columns, project_id)

    json = create_json(active_cards, columns)

    render(conn, "index.html", json: json)
  end

  def workflows(conn, _params) do
    json = request_spaces()

    render(conn, "workflows.html", json: json)
  end

  def token(), do: ''

  defp request_stories(columns, project_id) do
    if %HTTPoison.Response{status_code: 200, body: body} = get_stories(project_id) do
      columns_ids = Enum.map(columns, fn x -> x["id"] end)

      Enum.filter(Jason.decode!(body), fn x ->
        x["workflow_state_id"] in columns_ids
      end)
    else
      nil
    end
  end

  defp request_workflows(project_id) do
    if %HTTPoison.Response{status_code: 200, body: body} = get_workflows() do
      body
      |> Jason.decode!()
      |> Enum.filter(fn x -> Enum.member?(x["project_ids"], project_id) end)
      |> List.first()
      |> Map.get("states")
      |> Enum.filter(fn x -> x["type"] == "started" end)
    else
      nil
    end
  end

  defp request_spaces() do
    if %HTTPoison.Response{status_code: 200, body: body} = get_spaces() do
      body
      |> Jason.decode!()
    else
      nil
    end
  end

  defp get_spaces() do
    url = "https://api.clubhouse.io/api/v3/projects?token=#{token()}"

    HTTPoison.get!(url)
  end

  defp get_stories(project_id) do
    url = "https://api.clubhouse.io/api/v2/projects/#{project_id}/stories?token=#{token()}"

    HTTPoison.get!(url)
  end

  defp get_workflows do
    url = "https://api.clubhouse.io/api/v3/workflows?token=#{token()}"

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
    |> Enum.sort(&(&1.duration > &2.duration))
  end

  defp date_moved(moved_at) do
    {:ok, dt} = Elixir.Timex.Parse.DateTime.Parser.parse(moved_at, "{ISO:Extended:Z}")

    Timex.diff(Timex.now(), dt, :days)
  end

  defp find_column(workflow_state_id, columns) do
    Enum.find(columns, fn x -> workflow_state_id == x.id end).name
  end
end
