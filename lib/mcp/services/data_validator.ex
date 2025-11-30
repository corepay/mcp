defmodule Mcp.Services.DataValidator do
  @moduledoc """
  Service for validating data records against defined rules.
  Handles field validation, cross-field constraints, data integrity, and compliance.
  """

  def validate_record(nil, _), do: :ok
  def validate_record(_, rules) when rules == %{}, do: :ok

  def validate_record(record, rules) do
    field_rules = Map.get(rules, "fields", %{})
    cross_field_constraints = Map.get(rules, "cross_field_constraints", [])

    with :ok <- validate_fields(record, field_rules),
         :ok <- validate_cross_field_constraints(record, cross_field_constraints) do
      :ok
    end
  end

  def validate_records(records, rules) do
    results = Enum.map(records, fn record ->
      case validate_record(record, rules) do
        :ok -> {:ok, record}
        {:error, errors} -> {:error, %{record: record, errors: errors}}
      end
    end)

    valid_records = Enum.filter(results, fn {status, _} -> status == :ok end) |> Enum.map(fn {_, r} -> r end)
    invalid_records = Enum.filter(results, fn {status, _} -> status == :error end) |> Enum.map(fn {_, r} -> r end)

    %{
      total_records: length(records),
      valid_count: length(valid_records),
      invalid_count: length(invalid_records),
      valid_records: valid_records,
      invalid_records: invalid_records,
      validation_summary: generate_summary(invalid_records)
    }
  end

  def validate_data_integrity(records, rules) do
    unique_constraints = Map.get(rules, "unique_constraints", %{})

    errors =
      Enum.reduce(unique_constraints, [], fn {constraint_name, fields}, acc ->
        if has_duplicates?(records, fields) do
          acc ++ [%{error: "unique_constraint_violation", constraint: constraint_name}]
        else
          acc
        end
      end)

    if Enum.empty?(errors) do
      {:ok, :integrity_valid}
    else
      {:error, errors}
    end
  end

  def validate_compliance(records, rules) do
    gdpr_enabled = get_in(rules, ["gdpr", "enabled"])

    if gdpr_enabled do
      errors =
        Enum.reduce(records, [], fn record, acc ->
          if sensitive_data_exposed?(record) do
            acc ++ [%{error: "gdpr_sensitive_data_exposed", record: record}]
          else
            acc
          end
        end)

      if Enum.empty?(errors) do
        {:ok, :compliant}
      else
        {:error, errors}
      end
    else
      {:ok, :compliant}
    end
  end

  def generate_isp_validation_rules("customer") do
    %{
      "fields" => %{
        "customer_id" => %{"required" => true},
        "first_name" => %{"required" => true},
        "email" => %{"type" => "email", "required" => true},
        "service_type" => %{"enum" => ["residential_basic", "business_standard"]}
      },
      "business_rules" => %{},
      "cross_field_constraints" => []
    }
  end

  def generate_isp_validation_rules("billing") do
    %{
      "fields" => %{
        "account_number" => %{"required" => true},
        "base_amount" => %{"type" => "float"},
        "total_amount" => %{"type" => "float"}
      },
      "business_rules" => %{},
      "cross_field_constraints" => [
        %{
          "field1" => "total_amount",
          "operator" => "greater_equal",
          "field2" => "base_amount"
        }
      ]
    }
  end

  def generate_isp_validation_rules("network") do
    %{
      "fields" => %{
        "customer_id" => %{"required" => true},
        "ip_address" => %{"pattern" => "^(?:\\d{1,3}\\.){3}\\d{1,3}$"},
        "service_status" => %{}
      },
      "business_rules" => %{},
      "cross_field_constraints" => []
    }
  end

  def generate_isp_validation_rules(_), do: %{}

  # Private Helpers

  defp validate_fields(record, rules) do
    errors =
      Enum.reduce(rules, [], fn {field, rule}, acc ->
        value = Map.get(record, field)
        
        cond do
          rule["required"] == true and (is_nil(value) or value == "") ->
            acc ++ [%{error: "required_field_missing", field: field}]
            
          is_nil(value) ->
            acc
            
          true ->
            acc ++ validate_value(field, value, rule)
        end
      end)

    if Enum.empty?(errors), do: :ok, else: {:error, errors}
  end

  defp validate_value(field, value, rule) do
    errors = []
    
    errors = if rule["type"] == "string" and is_binary(value) do
      errors
      |> check_min_length(value, rule["min_length"])
      |> check_max_length(value, rule["max_length"])
      |> check_enum(value, rule["enum"])
    else
      errors
    end

    errors = if rule["type"] == "integer" and is_integer(value) do
      errors
      |> check_min_value(value, rule["min_value"])
      |> check_max_value(value, rule["max_value"])
    else
      errors
    end
    
    errors = if rule["type"] == "float" and is_number(value) do
      errors
      |> check_positive(value, rule["positive"])
    else
      errors
    end
    
    errors = if rule["type"] == "email" do
      if Regex.match?(~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/, value) do
        errors
      else
        errors ++ [%{error: "invalid_email", field: field}]
      end
    else
      errors
    end
    
    errors = if rule["type"] == "phone" do
      # Simple check for at least 7 digits
      digits = String.replace(value, ~r/\D/, "")
      if String.length(digits) >= 7 do
        errors
      else
        errors ++ [%{error: "invalid_phone", field: field}]
      end
    else
      errors
    end
    
    errors = if rule["min_items"] && is_list(value) do
      if length(value) >= rule["min_items"] do
        errors
      else
        errors ++ [%{error: "min_items_violation", field: field}]
      end
    else
      errors
    end

    errors
  end

  defp check_min_length(errors, value, min) when is_integer(min) do
    if String.length(value) >= min, do: errors, else: errors ++ [%{error: "min_length_violation"}]
  end
  defp check_min_length(errors, _, _), do: errors

  defp check_max_length(errors, value, max) when is_integer(max) do
    if String.length(value) <= max, do: errors, else: errors ++ [%{error: "max_length_violation"}]
  end
  defp check_max_length(errors, _, _), do: errors

  defp check_min_value(errors, value, min) when is_integer(min) do
    if value >= min, do: errors, else: errors ++ [%{error: "min_value_violation"}]
  end
  defp check_min_value(errors, _, _), do: errors

  defp check_max_value(errors, value, max) when is_integer(max) do
    if value <= max, do: errors, else: errors ++ [%{error: "max_value_violation"}]
  end
  defp check_max_value(errors, _, _), do: errors
  
  defp check_positive(errors, value, true) do
    if value >= 0, do: errors, else: errors ++ [%{error: "negative_value"}]
  end
  defp check_positive(errors, _, _), do: errors

  defp check_enum(errors, value, enum) when is_list(enum) do
    if value in enum, do: errors, else: errors ++ [%{error: "invalid_enum_value"}]
  end
  defp check_enum(errors, _, _), do: errors

  defp validate_cross_field_constraints(record, constraints) do
    errors =
      Enum.reduce(constraints, [], fn constraint, acc ->
        case constraint["type"] do
          "conditional_required" ->
            condition = constraint["condition"]
            if Map.get(record, condition["field"]) == condition["value"] do
              Enum.reduce(constraint["required_fields"], acc, fn field, inner_acc ->
                if Map.get(record, field) do
                  inner_acc
                else
                  inner_acc ++ [%{error: "conditional_required_violation", field: field}]
                end
              end)
            else
              acc
            end
            
          "field_comparison" ->
            val1 = Map.get(record, constraint["field1"])
            val2 = Map.get(record, constraint["field2"])
            
            valid = case constraint["operator"] do
              "greater_than" -> val1 > val2
              "greater_equal" -> val1 >= val2
              _ -> true
            end
            
            if valid, do: acc, else: acc ++ [%{error: "field_comparison_violation"}]
            
          _ -> acc
        end
      end)

    if Enum.empty?(errors), do: :ok, else: {:error, errors}
  end

  defp generate_summary(invalid_records) do
    %{
      total_errors: length(invalid_records),
      error_types: %{},
      most_common_error: "unknown"
    }
  end

  defp has_duplicates?(records, fields) do
    values = Enum.map(records, fn r -> 
      Enum.map(fields, &Map.get(r, &1)) 
    end)
    length(values) != length(Enum.uniq(values))
  end

  defp sensitive_data_exposed?(record) do
    # Simple check: if any field looks like a credit card (16 digits) and isn't masked
    Enum.any?(record, fn {_, value} ->
      is_binary(value) and Regex.match?(~r/^\d{16}$/, value)
    end)
  end
end
