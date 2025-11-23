defmodule Mcp.Platform.TenantBranding.Changes do
  @moduledoc """
  Changes module for tenant branding validation and transformations.
  """

  @doc """
  Validates color hex codes and ensures proper formatting.
  """
  def validate_colors(changeset, _opts) do
    changeset
    |> validate_color(:primary_color)
    |> validate_color(:secondary_color)
    |> validate_color(:accent_color)
    |> validate_color(:background_color)
    |> validate_color(:text_color)
    |> validate_color_contrast()
  end

  defp validate_color(changeset, field) do
    case Ash.Changeset.get_attribute(changeset, field) do
      nil ->
        changeset

      color ->
        if valid_hex_color?(color) do
          changeset
        else
          Ash.Changeset.add_error(changeset, field, "must be a valid hex color (e.g., #FF0000)")
        end
    end
  end

  defp validate_color_contrast(changeset) do
    primary_color = Ash.Changeset.get_attribute(changeset, :primary_color)
    background_color = Ash.Changeset.get_attribute(changeset, :background_color)
    text_color = Ash.Changeset.get_attribute(changeset, :text_color)

    cond do
      primary_color && background_color ->
        if has_sufficient_contrast?(primary_color, background_color, 3.0) do
          changeset
        else
          Ash.Changeset.add_error(
            changeset,
            :primary_color,
            "does not have sufficient contrast with background color"
          )
        end

      text_color && background_color ->
        if has_sufficient_contrast?(text_color, background_color, 4.5) do
          changeset
        else
          Ash.Changeset.add_error(
            changeset,
            :text_color,
            "does not have sufficient contrast with background color for accessibility"
          )
        end

      true ->
        changeset
    end
  end

  defp valid_hex_color?(color) do
    String.match?(color, ~r/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/)
  end

  defp hex_to_rgb(hex) do
    hex = String.replace_leading(hex, "#", "")

    case String.length(hex) do
      3 ->
        # Convert 3-digit hex to 6-digit
        hex =
          hex
          |> String.graphemes()
          |> Enum.map(&String.duplicate(&1, 2))
          |> Enum.join()

        hex_to_rgb("#" <> hex)

      6 ->
        <<r::16, g::16, b::16>> = Base.decode16!(hex, case: :mixed)
        {r / 255, g / 255, b / 255}
    end
  end

  defp relative_luminance({r, g, b}) do
    # Calculate relative luminance according to WCAG 2.0
    r = if r <= 0.03928, do: r / 12.92, else: :math.pow((r + 0.055) / 1.055, 2.4)
    g = if g <= 0.03928, do: g / 12.92, else: :math.pow((g + 0.055) / 1.055, 2.4)
    b = if b <= 0.03928, do: b / 12.92, else: :math.pow((b + 0.055) / 1.055, 2.4)

    0.2126 * r + 0.7152 * g + 0.0722 * b
  end

  defp contrast_ratio(color1, color2) do
    lum1 = relative_luminance(hex_to_rgb(color1))
    lum2 = relative_luminance(hex_to_rgb(color2))

    (max(lum1, lum2) + 0.05) / (min(lum1, lum2) + 0.05)
  end

  defp has_sufficient_contrast?(color1, color2, minimum_ratio) do
    contrast_ratio(color1, color2) >= minimum_ratio
  end
end
