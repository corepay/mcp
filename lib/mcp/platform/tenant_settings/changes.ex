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

    case validate_value_by_type(value, value_type, validation_rules) do
      :ok ->
        changeset

      {:error, message} ->
        Ash.Changeset.add_error(changeset, :value, message)
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
    if !is_binary(value) do
      {:error, "Value must be a string"}
    else
      validate_string_rules(value, rules)
    end
  end

  defp validate_value_by_type(value, :integer, rules) do
    if !is_integer(value) do
      {:error, "Value must be an integer"}
    else
      validate_numeric_rules(value, rules)
    end
  end

  defp validate_value_by_type(value, :float, rules) do
    if !is_number(value) do
      {:error, "Value must be a number"}
    else
      validate_numeric_rules(value, rules)
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
    if !is_map(value) do
      {:error, "Value must be a map"}
    else
      validate_map_rules(value, rules)
    end
  end

  defp validate_value_by_type(value, :array, rules) do
    if !is_list(value) do
      {:error, "Value must be an array"}
    else
      validate_array_rules(value, rules)
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
    cond do
      min_length = Map.get(rules, "min_length") ->
        if String.length(value) < min_length do
          {:error, "String must be at least #{min_length} characters"}
        else
          validate_string_rules(value, Map.delete(rules, "min_length"))
        end

      max_length = Map.get(rules, "max_length") ->
        if String.length(value) > max_length do
          {:error, "String must be at most #{max_length} characters"}
        else
          validate_string_rules(value, Map.delete(rules, "max_length"))
        end

      pattern = Map.get(rules, "pattern") ->
        if !Regex.match?(~r/#{pattern}/, value) do
          {:error, "String does not match required pattern"}
        else
          validate_string_rules(value, Map.delete(rules, "pattern"))
        end

      enum = Map.get(rules, "enum") ->
        if value not in enum do
          {:error, "Value must be one of: #{Enum.join(enum, ", ")}"}
        else
          validate_string_rules(value, Map.delete(rules, "enum"))
        end

      true ->
        :ok
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
    cond do
      required_keys = Map.get(rules, "required_keys") ->
        if !Enum.all?(required_keys, &Map.has_key?(value, &1)) do
          missing = Enum.reject(required_keys, &Map.has_key?(value, &1))
          {:error, "Missing required keys: #{Enum.join(missing, ", ")}"}
        else
          validate_map_rules(value, Map.delete(rules, "required_keys"))
        end

      allowed_keys = Map.get(rules, "allowed_keys") ->
        if !Enum.all?(Map.keys(value), fn key -> key in allowed_keys end) do
          extra = Enum.reject(Map.keys(value), &(&1 in allowed_keys))
          {:error, "Extra keys not allowed: #{Enum.join(extra, ", ")}"}
        else
          validate_map_rules(value, Map.delete(rules, "allowed_keys"))
        end

      true ->
        :ok
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
