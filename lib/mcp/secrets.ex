defmodule Mcp.Secrets do
  @moduledoc """
  Secrets management domain.
  """
  use Cloak.Vault, otp_app: :mcp
end
