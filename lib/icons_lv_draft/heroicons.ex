defmodule IconsLvDraft.Heroicons do
  @moduledoc """
  Integration with Heroicons library.

  This module provides functions for working with Heroicons SVG icons.
  """

  @doc """
  Import Heroicons into the IconsLv library.

  This function scans the Heroicons directories and copies the SVG files
  to the appropriate IconsLv category directories.
  """
  def import_heroicons() do
    # Path to Heroicons in the dependency
    heroicons_path = Application.app_dir(:heroicons, "optimized")

    # Import solid icons
    import_category(Path.join(heroicons_path, "24/solid"), "solid")

    # Import outline icons
    import_category(Path.join(heroicons_path, "24/outline"), "outline")

    :ok
  end

  defp import_category(source_path, category) do
    target_path = Application.app_dir(:icons_lv_draft, "priv/static/icons/#{category}")

    # Create the target directory if it doesn't exist
    File.mkdir_p!(target_path)

    # Get all SVG files in the source directory
    {:ok, files} = File.ls(source_path)

    # Copy each file to the target directory
    for file <- files, Path.extname(file) == ".svg" do
      source_file = Path.join(source_path, file)
      target_file = Path.join(target_path, file)

      # Read the SVG content
      svg_content = File.read!(source_file)

      # Write the SVG content to the target file
      File.write!(target_file, svg_content)
    end
  end

  @doc """
  Lists all available Heroicons.

  Returns a list of all Heroicons that have been imported into the IconsLv library.
  """
  def list_heroicons() do
    solid_icons = list_category("solid")
    outline_icons = list_category("outline")

    %{
      solid: solid_icons,
      outline: outline_icons
    }
  end

  defp list_category(category) do
    path = Application.app_dir(:icons_lv_darft, "priv/static/icons/#{category}")

    case File.ls(path) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".svg"))
        |> Enum.map(&Path.basename(&1, ".svg"))
        |> Enum.sort()

      {:error, _} ->
        []
    end
  end
end
