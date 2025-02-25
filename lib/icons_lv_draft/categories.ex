defmodule IconsLvDraft.Categories do
  @moduledoc """
  Provides functions for working with icon categories.
  """

  @doc """
  Returns a list of all available icon categories.
  """
  def all do
    Application.get_env(:icons_lv_draft, :categories, [
      %{id: "solid", name: "Solid", description: "Filled style icons"},
      %{id: "outline", name: "Outline", description: "Line style icons"},
      %{id: "transportation", name: "Transportation", description: "Vehicle and transport icons"}
    ])
  end

  @doc """
  Returns a list of all icons in a specific category.
  """
  def list_icons(category) do
    icons_path = Application.app_dir(:icons_lv_draft, "priv/static/icons/#{category}")

    case File.ls(icons_path) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".svg"))
        |> Enum.map(fn file ->
          name = Path.basename(file, ".svg")
          %{
            id: name,
            name: format_name(name),
            path: "#{category}/#{name}"
          }
        end)
        |> Enum.sort_by(& &1.name)

      {:error, _} ->
        []
    end
  end

  @doc """
  Returns a formatted, human-readable icon name.
  """
  def format_name(name) do
    name
    |> String.replace("-", " ")
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  @doc """
  Gets a category by ID.
  """
  def get_category(id) do
    Enum.find(all(), &(&1.id == id))
  end

  @doc """
  Adds a new category.

  This function adds a new category to the list of available categories
  and creates the corresponding directory if it doesn't exist.
  """
  def add_category(id, name, description) do
    # Get the current categories
    current_categories = all()

    # Check if the category already exists
    case Enum.find(current_categories, &(&1.id == id)) do
      nil ->
        # Add the new category
        new_category = %{id: id, name: name, description: description}
        updated_categories = current_categories ++ [new_category]

        # Update the configuration
        Application.put_env(:icons_lv_draft, :categories, updated_categories)

        # Create the directory if it doesn't exist
        icons_path = Application.app_dir(:icons_lv_draft, "priv/static/icons/#{id}")
        File.mkdir_p!(icons_path)

        {:ok, new_category}

      existing_category ->
        {:error, :already_exists, existing_category}
    end
  end
end
