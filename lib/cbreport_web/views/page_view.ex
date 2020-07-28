defmodule CbreportWeb.PageView do
  use CbreportWeb, :view

  def link_project(id), do: "/?project_id=#{id}"
end
