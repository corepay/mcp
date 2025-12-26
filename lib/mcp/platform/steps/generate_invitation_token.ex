defmodule Mcp.Platform.Steps.GenerateInvitationToken do
  @moduledoc """
  Generates a secure random token for invitations.
  """
  use Reactor.Step

  def run(_arguments, _context, _options) do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    {:ok, token}
  end
end
