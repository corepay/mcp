defmodule Security do
  @moduledoc """
  Security helper module.
  """

  def validate_login_attempt(_email, _ip, user_agent) do
    if String.contains?(String.downcase(user_agent || ""), "curl") do
      {:error, :suspicious_user_agent}
    else
      :ok
    end
  end

  def handle_security_incident(_type, _user_id, _details) do
    :ok
  end
end
