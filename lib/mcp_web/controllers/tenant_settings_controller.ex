defmodule McpWeb.TenantSettingsController do
  use McpWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end

  def dashboard(conn, _params) do
    render(conn, :dashboard)
  end

  def import_export(conn, _params) do
    render(conn, :import_export)
  end

  def export_settings(conn, _params) do
    send_download(conn, {:binary, "settings"}, filename: "settings.json")
  end

  def import_settings(conn, _params) do
    conn
    |> put_flash(:info, "Settings imported")
    |> redirect(to: ~p"/test/settings")
  end

  def features(conn, _params) do
    render(conn, :features)
  end

  def toggle_feature(conn, _params) do
    conn
    |> put_flash(:info, "Feature toggled")
    |> redirect(to: ~p"/test/settings/features")
  end

  def branding(conn, _params) do
    render(conn, :branding)
  end

  def update_branding(conn, _params) do
    conn
    |> put_flash(:info, "Branding updated")
    |> redirect(to: ~p"/test/settings/branding")
  end

  def show_category(conn, _params) do
    render(conn, :show_category)
  end

  def update_category(conn, _params) do
    conn
    |> put_flash(:info, "Category updated")
    |> redirect(to: ~p"/test/settings")
  end

  def edit_category(conn, _params) do
    render(conn, :edit_category)
  end
end
