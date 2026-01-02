defmodule McpWeb.AuthLive.LoginComponentTest do
  use ExUnit.Case, async: true

  alias McpWeb.AuthLive.{Login, LoginComponent}

  # Basic test to ensure the LiveView can be started
  test "Login LiveView has required callbacks" do
    # The Login LiveView delegates events to LoginComponent
    Code.ensure_loaded(Login)
    assert function_exported?(Login, :mount, 3)
    assert function_exported?(Login, :render, 1)
    assert function_exported?(Login, :handle_params, 3)
  end

  # Test that the LoginComponent (which handles events) exists
  test "LoginComponent LiveComponent has required handlers" do
    Code.ensure_loaded(LoginComponent)
    assert function_exported?(LoginComponent, :mount, 1)
    assert function_exported?(LoginComponent, :update, 2)
    assert function_exported?(LoginComponent, :handle_event, 3)
  end
end
