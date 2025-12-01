defmodule Mcp.Platform.TenantSettings.Changes do
  @moduledoc """
  Changes module for tenant settings validation and transformations.
  """

  @doc """
  Validates the setting value based on validation rules and value type.
  """
  def validate_value(changeset, _opts) do
    value = Ash.Changeset.get_attribute(changeset, :value)
    value_type = Ash.Changeset.get_attribute(changeset, :value_type)
    validation_rules = Ash.Changeset.get_attribute(changeset, :validation_rules)

    if is_nil(value) do
      changeset
    else
      case validate_value_by_type(value, value_type, validation_rules) do
        :ok ->
          changeset

        {:error, message} ->
          error =
            Ash.Error.Changes.InvalidAttribute.exception(
              field: :value,
              message: message,
              value: value
            )

          Ash.Changeset.add_error(changeset, error)
      end
    end
  end

  @doc """
  Encrypts the value if it's marked as encrypted.
  """
  def encrypt_value(changeset, _opts) do
    encrypted = Ash.Changeset.get_attribute(changeset, :encrypted)
    value = Ash.Changeset.get_attribute(changeset, :value)

    if encrypted && value do
      encrypted_value = encrypt_setting_value(value)
      Ash.Changeset.change_attribute(changeset, :value, encrypted_value)
    else
      changeset
    end
  end

  defp validate_value_by_type(value, :string, rules) do
    if is_binary(value) do
      validate_string_rules(value, rules)
    else
      {:error, "Value must be a string"}
    end
  end

  defp validate_value_by_type(value, :integer, rules) do
    if is_integer(value) do
      validate_numeric_rules(value, rules)
    else
      {:error, "Value must be an integer"}
    end
  end

  defp validate_value_by_type(value, :float, rules) do
    if is_number(value) do
      validate_numeric_rules(value, rules)
    else
      {:error, "Value must be a number"}
    end
  end

  defp validate_value_by_type(value, :boolean, _rules) do
    if is_boolean(value) do
      :ok
    else
      {:error, "Value must be a boolean"}
    end
  end

  defp validate_value_by_type(value, :map, rules) do
    if is_map(value) do
      validate_map_rules(value, rules)
    else
      {:error, "Value must be a map"}
    end
  end

  defp validate_value_by_type(value, :array, rules) do
    if is_list(value) do
      validate_array_rules(value, rules)
    else
      {:error, "Value must be an array"}
    end
  end

  defp validate_value_by_type(value, :json, _rules) do
    # JSON can be string, map, or array
    if is_binary(value) or is_map(value) or is_list(value) do
      :ok
    else
      {:error, "Value must be valid JSON (string, map, or array)"}
    end
  end

  defp validate_string_rules(value, rules) do
    with :ok <- validate_min_length(value, rules),
         :ok <- validate_max_length(value, rules),
         :ok <- validate_pattern(value, rules),
         :ok <- validate_enum(value, rules) do
      :ok
    else
      {:error, _reason} = error -> error
    end
  end

  defp validate_min_length(value, rules) do
    case Map.get(rules, "min_length") do
      nil ->
        :ok

      min_length ->
        if String.length(value) < min_length do
          {:error, "String must be at least #{min_length} characters"}
        else
          :ok
        end
    end
  end

  defp validate_max_length(value, rules) do
    case Map.get(rules, "max_length") do
      nil ->
        :ok

      max_length ->
        if String.length(value) > max_length do
          {:error, "String must be at most #{max_length} characters"}
        else
          :ok
        end
    end
  end

  defp validate_pattern(value, rules) do
    case Map.get(rules, "pattern") do
      nil ->
        :ok

      pattern ->
        if Regex.match?(~r/#{pattern}/, value) do
          :ok
        else
          {:error, "String does not match required pattern"}
        end
    end
  end

  defp validate_enum(value, rules) do
    case Map.get(rules, "enum") do
      nil ->
        :ok

      enum ->
        if value in enum do
          :ok
        else
          {:error, "Value must be one of: #{Enum.join(enum, ", ")}"}
        end
    end
  end

  defp validate_numeric_rules(value, rules) do
    cond do
      min_value = Map.get(rules, "min_value") ->
        if value < min_value do
          {:error, "Value must be at least #{min_value}"}
        else
          validate_numeric_rules(value, Map.delete(rules, "min_value"))
        end

      max_value = Map.get(rules, "max_value") ->
        if value > max_value do
          {:error, "Value must be at most #{max_value}"}
        else
          validate_numeric_rules(value, Map.delete(rules, "max_value"))
        end

      true ->
        :ok
    end
  end

  defp validate_map_rules(value, rules) do
    with :ok <- validate_required_keys(value, rules),
         :ok <- validate_allowed_keys(value, rules) do
      :ok
    else
      {:error, _reason} = error -> error
    end
  end

  defp validate_required_keys(value, rules) do
    case Map.get(rules, "required_keys") do
      nil ->
        :ok

      required_keys ->
        if Enum.all?(required_keys, &Map.has_key?(value, &1)) do
          :ok
        else
          missing = Enum.reject(required_keys, &Map.has_key?(value, &1))
          {:error, "Missing required keys: #{Enum.join(missing, ", ")}"}
        end
    end
  end

  defp validate_allowed_keys(value, rules) do
    allowed_keys = Map.get(rules, "allowed_keys")

    if allowed_keys == nil do
      :ok
    else
      validate_keys_allowed(Map.keys(value), allowed_keys)
    end
  end

  defp validate_keys_allowed(keys, allowed_keys) do
    if Enum.all?(keys, &(&1 in allowed_keys)) do
      :ok
    else
      extra = Enum.reject(keys, &(&1 in allowed_keys))
      {:error, "Extra keys not allowed: #{Enum.join(extra, ", ")}"}
    end
  end

  defp validate_array_rules(value, rules) do
    cond do
      min_items = Map.get(rules, "min_items") ->
        if length(value) < min_items do
          {:error, "Array must have at least #{min_items} items"}
        else
          validate_array_rules(value, Map.delete(rules, "min_items"))
        end

      max_items = Map.get(rules, "max_items") ->
        if length(value) > max_items do
          {:error, "Array must have at most #{max_items} items"}
        else
          validate_array_rules(value, Map.delete(rules, "max_items"))
        end

      true ->
        :ok
    end
  end

  defp encrypt_setting_value(value) do
    # Use a simple encryption for now - in production you'd want to use proper encryption
    # This is just a placeholder implementation
    if is_binary(value) do
      Base.encode64(
        :crypto.hash(:sha256, value <> System.get_env("ENCRYPTION_SALT", "default_salt"))
      )
    else
      encrypted_json = Jason.encode!(%{encrypted: value})

      Base.encode64(
        :crypto.hash(:sha256, encrypted_json <> System.get_env("ENCRYPTION_SALT", "default_salt"))
      )
    end
  end
end
