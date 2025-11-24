defmodule Mcp.Accounts.TOTP do
  @moduledoc """
  Time-based One-Time Password (TOTP) authentication using NimbleTOTP.
  
  Implements 2FA with:
  - TOTP secret generation
  - QR code generation for authenticator apps
  - Backup codes for account recovery
  - Code verification
  """

  alias Mcp.Accounts.User

  @backup_code_count 10
  @backup_code_length 8

  @doc """
  Generates a TOTP secret for a user.
  
  Returns a base32-encoded secret that can be used with authenticator apps.
  """
  def generate_secret(_user) do
    secret = NimbleTOTP.secret()
    {:ok, secret}
  end

  @doc """
  Verifies a TOTP code against the user's secret.
  
  Returns :ok if valid, {:error, reason} otherwise.
  """
  def verify_code(user, code) when is_binary(code) do
    case user.totp_secret do
      nil ->
        {:error, :totp_not_enabled}
        
      secret ->
        if NimbleTOTP.valid?(secret, code) do
          :ok
        else
          {:error, :invalid_code}
        end
    end
  end

  @doc """
  Verifies a backup code.
  
  Returns {:ok, user} with the code removed if valid.
  """
  def verify_backup_code(user, code) when is_binary(code) do
    backup_codes = user.backup_codes || []
    
    # Hash the provided code to compare with stored hashes
    code_hash = hash_backup_code(code)
    
    if code_hash in backup_codes do
      # Remove the used backup code
      new_backup_codes = List.delete(backup_codes, code_hash)
      
      case User.update(user, %{backup_codes: new_backup_codes}) do
        {:ok, updated_user} -> {:ok, updated_user}
        error -> error
      end
    else
      {:error, :invalid_backup_code}
    end
  end

  @doc """
  Enables TOTP for a user with the provided secret.
  
  Returns {:ok, user, backup_codes} on success.
  """
  def enable_totp(user, secret) do
    with {:ok, backup_codes} <- generate_backup_codes(user),
         hashed_codes = Enum.map(backup_codes, &hash_backup_code/1),
         {:ok, updated_user} <- User.update(user, %{
           totp_secret: secret,
           backup_codes: hashed_codes
         }) do
      {:ok, updated_user, backup_codes}
    end
  end

  @doc """
  Disables TOTP for a user.
  """
  def disable_totp(user) do
    if totp_enabled?(user) do
      case User.update(user, %{totp_secret: nil, backup_codes: []}) do
        {:ok, updated_user} -> {:ok, updated_user}
        error -> error
      end
    else
      {:error, :totp_not_enabled}
    end
  end

  @doc """
  Generates backup codes for account recovery.
  
  Returns {:ok, [codes]} - plain text codes (only shown once).
  """
  def generate_backup_codes(_user) do
    codes = for _ <- 1..@backup_code_count do
      generate_backup_code()
    end
    
    {:ok, codes}
  end

  @doc """
  Checks if TOTP is enabled for a user.
  """
  def totp_enabled?(user) do
    not is_nil(user.totp_secret)
  end

  @doc """
  Verifies a TOTP code (alias for verify_code/2).
  """
  def verify_totp_code(user, code) do
    verify_code(user, code)
  end

  @doc """
  Sets up TOTP for a user.
  
  Returns {:ok, setup_data} with secret, QR code URI, and backup codes.
  """
  def setup_totp(user) do
    with {:ok, secret} <- generate_secret(user),
         qr_uri <- generate_qr_uri(user.email, secret),
         {:ok, backup_codes} <- generate_backup_codes(user) do
      {:ok, %{
        secret: secret,
        qr_code_uri: qr_uri,
        backup_codes: backup_codes
      }}
    end
  end

  @doc """
  Regenerates backup codes for a user.
  
  Replaces all existing backup codes with new ones.
  """
  def regenerate_backup_codes(user) do
    if totp_enabled?(user) do
      with {:ok, backup_codes} <- generate_backup_codes(user),
           hashed_codes = Enum.map(backup_codes, &hash_backup_code/1),
           {:ok, updated_user} <- User.update(user, %{backup_codes: hashed_codes}) do
        {:ok, updated_user, backup_codes}
      end
    else
      {:error, :totp_not_enabled}
    end
  end

  @doc """
  Generates a QR code URI for authenticator apps.
  
  Format: otpauth://totp/MCP:email?secret=SECRET&issuer=MCP
  """
  def generate_qr_uri(email, secret) do
    issuer = Application.get_env(:mcp, :totp_issuer, "MCP Platform")
    label = "#{issuer}:#{email}"
    
    NimbleTOTP.otpauth_uri(label, secret, issuer: issuer)
  end

  # Private functions

  defp generate_backup_code do
    :crypto.strong_rand_bytes(@backup_code_length)
    |> Base.encode32(padding: false)
    |> binary_part(0, @backup_code_length)
  end

  defp hash_backup_code(code) do
    :crypto.hash(:sha256, code)
    |> Base.encode16(case: :lower)
  end
end