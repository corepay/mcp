defmodule Mcp.Services.DataValidatorTest do
  @moduledoc """
  Unit tests for DataValidator service.
  """

  use ExUnit.Case, async: true
  alias Mcp.Services.DataValidator

  describe "validate_record/2" do
    test "validates record with no rules" do
      record = %{"name" => "John", "age" => 25}
      validation_rules = %{}

      result = DataValidator.validate_record(record, validation_rules)

      assert result == :ok
    end

    test "validates required fields" do
      record = %{"name" => "John", "email" => "john@example.com"}

      validation_rules = %{
        "fields" => %{
          "name" => %{"required" => true},
          "email" => %{"required" => true},
          "phone" => %{"required" => false}
        }
      }

      result = DataValidator.validate_record(record, validation_rules)

      assert result == :ok
    end

    test "detects missing required fields" do
      # Missing required email
      record = %{"name" => "John"}

      validation_rules = %{
        "fields" => %{
          "name" => %{"required" => true},
          "email" => %{"required" => true}
        }
      }

      result = DataValidator.validate_record(record, validation_rules)

      assert {:error, errors} = result
      assert length(errors) == 1
      assert hd(errors)[:error] == "required_field_missing"
      assert hd(errors)[:field] == "email"
    end

    test "validates string length constraints" do
      record = %{"name" => "John"}

      validation_rules = %{
        "fields" => %{
          "name" => %{
            "type" => "string",
            "min_length" => 2,
            "max_length" => 10
          }
        }
      }

      # Valid length
      result = DataValidator.validate_record(record, validation_rules)
      assert result == :ok

      # Too short
      short_record = %{"name" => "J"}
      result = DataValidator.validate_record(short_record, validation_rules)
      assert {:error, errors} = result
      assert hd(errors)[:error] == "min_length_violation"

      # Too long
      long_record = %{"name" => "Very Long Name That Exceeds Limit"}
      result = DataValidator.validate_record(long_record, validation_rules)
      assert {:error, errors} = result
      assert hd(errors)[:error] == "max_length_violation"
    end

    test "validates email format" do
      validation_rules = %{
        "fields" => %{
          "email" => %{"type" => "email", "required" => true}
        }
      }

      # Valid email
      valid_record = %{"email" => "john@example.com"}
      result = DataValidator.validate_record(valid_record, validation_rules)
      assert result == :ok

      # Invalid email
      invalid_record = %{"email" => "not-an-email"}
      result = DataValidator.validate_record(invalid_record, validation_rules)
      assert {:error, errors} = result
      assert hd(errors)[:error] == "invalid_email"
    end

    test "validates phone format" do
      validation_rules = %{
        "fields" => %{
          "phone" => %{"type" => "phone"}
        }
      }

      # Valid phone
      valid_record = %{"phone" => "(555) 123-4567"}
      result = DataValidator.validate_record(valid_record, validation_rules)
      assert result == :ok

      # Invalid phone (not enough digits)
      invalid_record = %{"phone" => "123"}
      result = DataValidator.validate_record(invalid_record, validation_rules)
      assert {:error, errors} = result
      assert hd(errors)[:error] == "invalid_phone"
    end

    test "validates number constraints" do
      record = %{"age" => 25}

      validation_rules = %{
        "fields" => %{
          "age" => %{
            "type" => "integer",
            "min_value" => 18,
            "max_value" => 100
          }
        }
      }

      # Valid range
      result = DataValidator.validate_record(record, validation_rules)
      assert result == :ok

      # Below minimum
      below_record = %{"age" => 16}
      result = DataValidator.validate_record(below_record, validation_rules)
      assert {:error, errors} = result
      assert hd(errors)[:error] == "min_value_violation"

      # Above maximum
      above_record = %{"age" => 150}
      result = DataValidator.validate_record(above_record, validation_rules)
      assert {:error, errors} = result
      assert hd(errors)[:error] == "max_value_violation"
    end

    test "validates positive numbers" do
      validation_rules = %{
        "fields" => %{
          "price" => %{
            "type" => "float",
            "positive" => true
          }
        }
      }

      # Positive number
      positive_record = %{"price" => 25.99}
      result = DataValidator.validate_record(positive_record, validation_rules)
      assert result == :ok

      # Negative number
      negative_record = %{"price" => -10.0}
      result = DataValidator.validate_record(negative_record, validation_rules)
      assert {:error, errors} = result
      assert hd(errors)[:error] == "negative_value"
    end

    test "validates enum values" do
      validation_rules = %{
        "fields" => %{
          "status" => %{
            "type" => "string",
            "enum" => ["active", "inactive", "pending"]
          }
        }
      }

      # Valid enum value
      valid_record = %{"status" => "active"}
      result = DataValidator.validate_record(valid_record, validation_rules)
      assert result == :ok

      # Invalid enum value
      invalid_record = %{"status" => "unknown"}
      result = DataValidator.validate_record(invalid_record, validation_rules)
      assert {:error, errors} = result
      assert hd(errors)[:error] == "invalid_enum_value"
    end

    test "validates array constraints" do
      validation_rules = %{
        "fields" => %{
          "tags" => %{
            "min_items" => 1
          }
        }
      }

      # Valid array
      valid_record = %{"tags" => ["tag1", "tag2"]}
      result = DataValidator.validate_record(valid_record, validation_rules)
      assert result == :ok

      # Empty array
      empty_record = %{"tags" => []}
      result = DataValidator.validate_record(empty_record, validation_rules)
      assert {:error, errors} = result
      assert hd(errors)[:error] == "min_items_violation"
    end

    test "validates cross-field constraints" do
      validation_rules = %{
        "fields" => %{
          "has_phone_service" => %{"type" => "boolean"},
          "phone_number" => %{"type" => "string"}
        },
        "cross_field_constraints" => [
          %{
            "type" => "conditional_required",
            "condition" => %{
              "field" => "has_phone_service",
              "operator" => "equals",
              "value" => true
            },
            "required_fields" => ["phone_number"]
          }
        ]
      }

      # Phone service with phone number - should pass
      valid_record = %{"has_phone_service" => true, "phone_number" => "555-1234"}
      result = DataValidator.validate_record(valid_record, validation_rules)
      assert result == :ok

      # Phone service without phone number - should fail
      invalid_record = %{"has_phone_service" => true}
      result = DataValidator.validate_record(invalid_record, validation_rules)
      assert {:error, errors} = result
      assert hd(errors)[:error] == "conditional_required_violation"

      # No phone service - should pass even without phone number
      no_service_record = %{"has_phone_service" => false}
      result = DataValidator.validate_record(no_service_record, validation_rules)
      assert result == :ok
    end

    test "validates field comparisons" do
      validation_rules = %{
        "fields" => %{
          "start_date" => %{"type" => "string"},
          "end_date" => %{"type" => "string"}
        },
        "cross_field_constraints" => [
          %{
            "type" => "field_comparison",
            "field1" => "end_date",
            "operator" => "greater_than",
            "field2" => "start_date"
          }
        ]
      }

      # Valid comparison
      valid_record = %{"start_date" => "2023-01-01", "end_date" => "2023-12-31"}
      result = DataValidator.validate_record(valid_record, validation_rules)
      assert result == :ok

      # Invalid comparison
      invalid_record = %{"start_date" => "2023-12-31", "end_date" => "2023-01-01"}
      result = DataValidator.validate_record(invalid_record, validation_rules)
      assert {:error, errors} = result
      assert hd(errors)[:error] == "field_comparison_violation"
    end

    test "applies business rules" do
      record = %{
        "first_name" => "John",
        "email" => "john@example.com",
        "base_amount" => 100.0,
        "total_amount" => 108.0
      }

      validation_rules = %{
        "fields" => %{
          "first_name" => %{"required" => true},
          "base_amount" => %{"type" => "float", "positive" => true},
          "total_amount" => %{"type" => "float", "positive" => true}
        },
        "business_rules" => %{
          "customer_validation" => %{},
          "billing_validation" => %{}
        }
      }

      result = DataValidator.validate_record(record, validation_rules)

      assert result == :ok
    end
  end

  describe "validate_records/2" do
    test "validates multiple records" do
      records = [
        %{"name" => "John", "age" => 25},
        %{"name" => "Jane", "age" => 30},
        # Invalid empty name
        %{"name" => "", "age" => 35}
      ]

      validation_rules = %{
        "fields" => %{
          "name" => %{"required" => true, "min_length" => 1},
          "age" => %{"type" => "integer", "min_value" => 18}
        }
      }

      result = DataValidator.validate_records(records, validation_rules)

      assert is_map(result)
      assert result.total_records == 3
      assert result.valid_count == 2
      assert result.invalid_count == 1
      assert length(result.valid_records) == 2
      assert length(result.invalid_records) == 1

      # Check invalid record details
      invalid_record = hd(result.invalid_records)
      assert is_map(invalid_record.record)
      assert is_list(invalid_record.errors)
    end

    test "handles empty record list" do
      result = DataValidator.validate_records([], %{})

      assert result.total_records == 0
      assert result.valid_count == 0
      assert result.invalid_count == 0
      assert result.valid_records == []
      assert result.invalid_records == []
    end

    test "generates validation summary" do
      records = [
        %{"name" => "John", "age" => 25},
        %{"name" => "", "age" => 30},
        # Missing name
        %{"age" => 35}
      ]

      validation_rules = %{
        "fields" => %{
          "name" => %{"required" => true},
          "age" => %{"type" => "integer"}
        }
      }

      result = DataValidator.validate_records(records, validation_rules)

      assert is_map(result.validation_summary)
      assert result.validation_summary.total_errors > 0
      assert is_map(result.validation_summary.error_types)
      assert is_binary(result.validation_summary.most_common_error)
    end
  end

  describe "validate_data_integrity/2" do
    test "validates unique constraints" do
      records = [
        %{"id" => "1", "email" => "john@example.com"},
        # Duplicate email
        %{"id" => "2", "email" => "john@example.com"},
        %{"id" => "3", "email" => "jane@example.com"}
      ]

      integrity_rules = %{
        "unique_constraints" => %{
          "unique_email" => ["email"]
        }
      }

      result = DataValidator.validate_data_integrity(records, integrity_rules)

      assert {:error, errors} = result
      assert length(errors) == 1
      assert hd(errors)[:error] == "unique_constraint_violation"
      assert hd(errors)[:constraint] == "unique_email"
    end

    test "validates composite unique constraints" do
      records = [
        %{"name" => "John", "department" => "IT"},
        # Duplicate composite key
        %{"name" => "John", "department" => "IT"},
        %{"name" => "John", "department" => "Sales"}
      ]

      integrity_rules = %{
        "unique_constraints" => %{
          "unique_name_department" => ["name", "department"]
        }
      }

      result = DataValidator.validate_data_integrity(records, integrity_rules)

      assert {:error, errors} = result
      assert hd(errors)[:constraint] == "unique_name_department"
    end

    test "passes when no integrity violations" do
      records = [
        %{"id" => "1", "email" => "john@example.com"},
        %{"id" => "2", "email" => "jane@example.com"}
      ]

      integrity_rules = %{
        "unique_constraints" => %{
          "unique_email" => ["email"]
        }
      }

      result = DataValidator.validate_data_integrity(records, integrity_rules)

      assert {:ok, :integrity_valid} = result
    end
  end

  describe "validate_compliance/2" do
    test "validates GDPR compliance" do
      records = [
        # Properly masked
        %{"name" => "John", "ssn" => "***MASKED***"},
        # Exposed
        %{"name" => "Jane", "credit_card" => "4111111111111111"}
      ]

      compliance_rules = %{
        "gdpr" => %{"enabled" => true},
        "pci" => %{"enabled" => false}
      }

      result = DataValidator.validate_compliance(records, compliance_rules)

      assert {:error, errors} = result
      assert length(errors) == 1
      assert hd(errors)[:error] == "gdpr_sensitive_data_exposed"
    end

    test "passes compliance validation with masked data" do
      records = [
        %{"name" => "John", "ssn" => "***MASKED***"},
        %{"name" => "Jane", "credit_card" => "***MASKED***"}
      ]

      compliance_rules = %{
        "gdpr" => %{"enabled" => true},
        "pci" => %{"enabled" => true}
      }

      result = DataValidator.validate_compliance(records, compliance_rules)

      assert {:ok, :compliant} = result
    end

    test "skips compliance when disabled" do
      records = [
        %{"name" => "John", "ssn" => "123-45-6789"}
      ]

      compliance_rules = %{
        "gdpr" => %{"enabled" => false}
      }

      result = DataValidator.validate_compliance(records, compliance_rules)

      assert {:ok, :compliant} = result
    end
  end

  describe "generate_isp_validation_rules/1" do
    test "generates customer validation rules" do
      result = DataValidator.generate_isp_validation_rules("customer")

      assert is_map(result)
      assert Map.has_key?(result, "fields")
      assert Map.has_key?(result, "business_rules")
      assert Map.has_key?(result, "cross_field_constraints")

      fields = result["fields"]
      assert Map.has_key?(fields, "customer_id")
      assert Map.has_key?(fields, "first_name")
      assert Map.has_key?(fields, "email")
      assert Map.has_key?(fields, "service_type")

      # Check specific field rules
      email_rule = fields["email"]
      assert email_rule["type"] == "email"
      assert email_rule["required"] == true

      service_type_rule = fields["service_type"]
      assert "residential_basic" in service_type_rule["enum"]
      assert "business_standard" in service_type_rule["enum"]
    end

    test "generates billing validation rules" do
      result = DataValidator.generate_isp_validation_rules("billing")

      assert is_map(result)
      fields = result["fields"]
      assert Map.has_key?(fields, "account_number")
      assert Map.has_key?(fields, "base_amount")
      assert Map.has_key?(fields, "total_amount")

      # Check business rules
      assert Map.has_key?(result, "business_rules")
      assert Map.has_key?(result, "cross_field_constraints")

      # Check cross-field constraints
      cross_constraints = result["cross_field_constraints"]
      assert length(cross_constraints) > 0

      total_amount_constraint =
        Enum.find(cross_constraints, fn c ->
          Map.get(c, "field1") == "total_amount" and Map.get(c, "operator") == "greater_equal"
        end)

      assert total_amount_constraint != nil
    end

    test "generates network validation rules" do
      result = DataValidator.generate_isp_validation_rules("network")

      assert is_map(result)
      fields = result["fields"]
      assert Map.has_key?(fields, "customer_id")
      assert Map.has_key?(fields, "ip_address")
      assert Map.has_key?(fields, "service_status")

      # Check IP address validation
      ip_rule = fields["ip_address"]
      assert is_binary(ip_rule["pattern"])
      assert String.contains?(ip_rule["pattern"], "\\d{1,3}")
    end

    test "returns empty rules for unknown data type" do
      result = DataValidator.generate_isp_validation_rules("unknown_type")

      assert result == %{}
    end
  end

  describe "edge cases and error handling" do
    test "handles nil record" do
      result = DataValidator.validate_record(nil, %{})

      assert result == :ok
    end

    test "handles empty validation rules" do
      record = %{"name" => "John"}

      result = DataValidator.validate_record(record, %{})

      assert result == :ok
    end

    test "handles record with nil values" do
      record = %{"name" => nil, "age" => nil}

      validation_rules = %{
        "fields" => %{
          "name" => %{"required" => false},
          "age" => %{"required" => false}
        }
      }

      result = DataValidator.validate_record(record, validation_rules)

      assert result == :ok
    end

    test "handles malformed validation rules" do
      record = %{"name" => "John"}

      validation_rules = %{
        "fields" => %{
          "name" => %{"invalid_rule" => "invalid_value"}
        }
      }

      result = DataValidator.validate_record(record, validation_rules)

      # Should handle gracefully - invalid rules should be ignored
      assert result == :ok
    end
  end
end
