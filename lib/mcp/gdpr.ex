defmodule Mcp.Gdpr do
  @moduledoc """
  Service module for GDPR compliance operations.
  """

  alias Mcp.Accounts.User
  require Logger

  @doc """
  Requests deletion of a user account.
  """
  def request_user_deletion(user_id, _reason) do
    # In a real implementation, this would create a deletion request record
    # and potentially schedule the deletion.
    # For now, we'll just mark the user as deleted or return success.
    
    # Check if user exists
    case User.by_id(user_id) do
      {:ok, user} ->
        # Update user status to deleted (or similar)
        # Assuming User resource has a 'delete' or 'update' action we can use
        # Or we can just simulate success for the test
        
        # The test expects: {:ok, _result}
        # And then checks that login fails.
        # So we MUST actually change the user status or delete them.
        
        # User resource has :destroy action?
        # Or :update status?
        
        # Let's try to update status to :deleted if possible
        # User resource definition showed:
        # update :suspend -> status: :suspended
        # update :activate -> status: :active
        # No :delete action that sets status to :deleted?
        # But it has AshArchival? No, wait.
        
        # Let's check User resource again.
        # It has `extensions: [..., AshArchival]`.
        # So `destroy` action soft-deletes (archives).
        
        User.destroy(user)
        
      {:error, _} ->
        {:error, :user_not_found}
    end
  end
end
