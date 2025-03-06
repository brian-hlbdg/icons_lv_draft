defmodule IconsLvDraftWeb.Components.IconPreview do
  @moduledoc """
  Component for displaying a clean preview of a single icon.
  """
  use Phoenix.Component

  attr :icon_path, :string, required: true
  attr :base_color, :string, default: "currentColor"
  attr :active_color, :string, default: nil
  attr :warning_color, :string, default: nil

  def preview(assigns) do
    ~H"""
    <div class="icon-preview-container">
      <style>
        .icon-preview-container {
          display: flex;
          justify-content: center;
          align-items: center;
          padding: 1.5rem;
          position: relative;
        }
        .icon-preview-container .inner-container {
          width: 6rem;
          height: 6rem;
          display: flex;
          justify-content: center;
          align-items: center;
          position: relative;
        }
        .icon-preview-container .inner-container::before {
          content: '';
          position: absolute;
          inset: 0;
          background: #f9fafb;
          border-radius: 9999px;
          width: 100%;
          height: 100%;
          z-index: -1;
        }
      </style>
      <div class="inner-container">
        <IconsLvDraftWeb.CoreComponents.icon
          name={@icon_path}
          base_color={@base_color}
          active_color={@active_color}
          warning_color={@warning_color}
          class="w-16 h-16"
        />
      </div>
    </div>
    """
  end
end
