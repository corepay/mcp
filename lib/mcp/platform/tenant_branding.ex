defmodule Mcp.Platform.TenantBranding do
  @moduledoc """
  Resource representing branding configuration for a tenant.
  """

  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer,
    extensions: [Ash.Resource.Dsl]

  alias Mcp.Platform.TenantBranding.Changes
  alias Mcp.Repo

  postgres do
    table "tenant_branding"
    repo(Repo)
  end

  actions do
    defaults [:read, :destroy]

    create :create_branding do
      primary? true

      accept [
        :tenant_id,
        :name,
        :primary_color,
        :secondary_color,
        :accent_color,
        :background_color,
        :text_color,
        :theme,
        :font_family,
        :logo_url,
        :created_by,
        :is_active
      ]

      change &Changes.validate_colors/2
    end

    update :update_branding do
      accept [
        :name,
        :primary_color,
        :secondary_color,
        :accent_color,
        :background_color,
        :text_color,
        :theme,
        :font_family,
        :logo_url,
        :is_active
      ]

      change &Changes.validate_colors/2
      require_atomic? false
    end

    update :activate do
      accept []
      change set_attribute(:is_active, true)
    end

    read :by_id do
      argument :id, :uuid, allow_nil?: false
      filter expr(id == ^arg(:id))
      get? true
    end
  end

  code_interface do
    define :create_branding
    define :update_branding
    define :activate
    define :by_id, args: [:id], get?: true
  end

  attributes do
    uuid_primary_key :id

    attribute :tenant_id, :uuid do
      allow_nil? false
    end

    attribute :name, :string do
      allow_nil? false
    end

    attribute :primary_color, :string
    attribute :secondary_color, :string
    attribute :accent_color, :string
    attribute :background_color, :string
    attribute :text_color, :string

    attribute :theme, :atom do
      constraints one_of: [:light, :dark, :system]
      default :light
    end

    attribute :font_family, :string
    attribute :logo_url, :string
    attribute :created_by, :string
    attribute :is_active, :boolean, default: false

    timestamps()
  end

  # Helper functions
  def get_branding_config(branding) do
    %{
      colors: %{
        primary: branding.primary_color,
        secondary: branding.secondary_color,
        accent: branding.accent_color,
        background: branding.background_color,
        text: branding.text_color
      },
      assets: %{
        logo: branding.logo_url
      },
      theme: branding.theme,
      fonts: %{
        primary: branding.font_family
      }
    }
  end

  def generate_css_variables(branding) do
    """
    :root {
      --primary-color: #{branding.primary_color};
      --secondary-color: #{branding.secondary_color};
      --background-color: #{branding.background_color};
      --text-color: #{branding.text_color};
      --font-family: #{branding.font_family};
    }
    """
  end
end
