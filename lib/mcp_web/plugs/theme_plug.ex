defmodule McpWeb.Plugs.ThemePlug do
  @moduledoc """
  Injects CSS variables for theming based on the current tenant or merchant context.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    theme = get_theme(conn)
    
    conn
    |> assign(:theme, theme)
    |> put_session(:theme, theme)
  end

  alias Mcp.Platform.TenantSettingsManager

  defp get_theme(conn) do
    case conn.assigns[:current_tenant] do
      nil ->
        %{}

      tenant ->
        case TenantSettingsManager.get_tenant_branding(tenant.id) do
          {:ok, branding} ->
            build_theme_variables(branding)

          _ ->
            %{}
        end
    end
  end

  defp build_theme_variables(branding) do
    colors = branding["colors"] || %{}
    assets = branding["assets"] || %{}
    fonts = branding["fonts"] || %{}

    %{
      "--color-primary" => colors["primary"],
      "--color-secondary" => colors["secondary"],
      "--color-accent" => colors["accent"],
      "--font-heading" => fonts["heading"],
      "--font-body" => fonts["body"],
      "--radius-box" => branding["radius"],
      "--logo-url" => "url('#{assets["logo"]}')"
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) or v == "" end)
    |> Map.new()
  end
end
