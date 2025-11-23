defmodule Mcp.Services.DataTransformerTest do
  @moduledoc """
  Unit tests for DataTransformer service.
  """

  use ExUnit.Case, async: true
  alias Mcp.Services.DataTransformer

  describe "transform_record/2" do
    test "transforms record with simple field mapping" do
      record = %{
        "first_name" => "John",
        "last_name" => "Doe",
        "age" => "25"
      }

      field_mappings = %{
        "name" => %{
          "source_field" => "first_name",
          "transformation" => "string"
        },
        "age_number" => %{
          "source_field" => "age",
          "transformation" => "integer"
        }
      }

      result = DataTransformer.transform_record(record, field_mappings)

      assert {:ok, transformed} = result
      assert transformed["name"] == "John"
      assert transformed["age_number"] == 25
      # Original record fields not mapped are not included
      assert is_nil(transformed["last_name"])
    end

    test "applies default values for missing fields" do
      record = %{
        "name" => "John"
      }

      field_mappings = %{
        "name" => %{
          "source_field" => "name",
          "transformation" => "string"
        },
        "status" => %{
          "source_field" => "active",
          "transformation" => "boolean",
          "default" => false
        }
      }

      result = DataTransformer.transform_record(record, field_mappings)

      assert {:ok, transformed} = result
      assert transformed["name"] == "John"
      assert transformed["status"] == false
    end

    test "handles required fields" do
      record = %{
        "name" => "John"
      }

      field_mappings = %{
        "name" => %{
          "source_field" => "name",
          "transformation" => "string",
          "required" => true
        },
        "email" => %{
          "source_field" => "email",
          "transformation" => "string",
          "required" => true
        }
      }

      result = DataTransformer.transform_record(record, field_mappings)

      assert {:ok, transformed} = result
      assert transformed["name"] == "John"
      # Required but missing - still returns nil
      assert is_nil(transformed["email"])
    end

    test "applies data type transformations" do
      record = %{
        "age_string" => "25",
        "price_string" => "19.99",
        "active_string" => "true"
      }

      field_mappings = %{
        "age" => %{
          "source_field" => "age_string",
          "transformation" => "integer"
        },
        "price" => %{
          "source_field" => "price_string",
          "transformation" => "float"
        },
        "active" => %{
          "source_field" => "active_string",
          "transformation" => "boolean"
        }
      }

      result = DataTransformer.transform_record(record, field_mappings)

      assert {:ok, transformed} = result
      assert transformed["age"] == 25
      assert transformed["price"] == 19.99
      assert transformed["active"] == true
    end

    test "applies function transformations" do
      record = %{
        "name" => "john doe",
        "email" => "JOHN.DOE@EXAMPLE.COM",
        "phone" => "(555) 123-4567"
      }

      field_mappings = %{
        "name_formatted" => %{
          "source_field" => "name",
          "transformation" => "function:capitalize_name"
        },
        "email_normalized" => %{
          "source_field" => "email",
          "transformation" => "function:normalize_email"
        },
        "phone_normalized" => %{
          "source_field" => "phone",
          "transformation" => "function:normalize_phone"
        }
      }

      result = DataTransformer.transform_record(record, field_mappings)

      assert {:ok, transformed} = result
      assert transformed["name_formatted"] == "John Doe"
      assert transformed["email_normalized"] == "john.doe@example.com"
      assert transformed["phone_normalized"] == "5551234567"
    end

    test "applies conditional transformations" do
      record = %{
        "account_type" => "premium",
        "base_fee" => "50"
      }

      field_mappings = %{
        "final_fee" => %{
          "source_field" => "base_fee",
          "transformation" => %{
            "type" => "conditional",
            "conditions" => [
              %{
                "condition" => %{
                  "field" => "account_type",
                  "operator" => "equals",
                  "value" => "premium"
                },
                "result" => 75
              },
              %{
                "condition" => %{
                  "field" => "account_type",
                  "operator" => "equals",
                  "value" => "basic"
                },
                "result" => 50
              }
            ],
            "default" => 25
          }
        }
      }

      result = DataTransformer.transform_record(record, field_mappings)

      assert {:ok, transformed} = result
      assert transformed["final_fee"] == 75
    end

    test "applies lookup transformations" do
      record = %{
        "plan_code" => "BASIC"
      }

      field_mappings = %{
        "plan_name" => %{
          "source_field" => "plan_code",
          "transformation" => %{
            "type" => "lookup",
            "lookup_table" => %{
              "BASIC" => "Basic Plan",
              "PREMIUM" => "Premium Plan",
              "ENTERPRISE" => "Enterprise Plan"
            },
            "default" => "Unknown Plan"
          }
        }
      }

      result = DataTransformer.transform_record(record, field_mappings)

      assert {:ok, transformed} = result
      assert transformed["plan_name"] == "Basic Plan"
    end

    test "handles transformation errors gracefully" do
      record = %{
        "invalid_number" => "not_a_number"
      }

      field_mappings = %{
        "number_field" => %{
          "source_field" => "invalid_number",
          "transformation" => "integer"
        }
      }

      result = DataTransformer.transform_record(record, field_mappings)

      assert {:ok, transformed} = result
      # Failed transformation should return default (nil)
      assert is_nil(transformed["number_field"])
    end

    test "handles nested field access" do
      record = %{
        "customer" => %{
          "personal" => %{
            "first_name" => "John",
            "last_name" => "Doe"
          }
        }
      }

      field_mappings = %{
        "first_name" => %{
          "source_field" => "customer.personal.first_name",
          "transformation" => "string"
        }
      }

      result = DataTransformer.transform_record(record, field_mappings)

      assert {:ok, transformed} = result
      assert transformed["first_name"] == "John"
    end
  end

  describe "transform_records/2" do
    test "transforms multiple records" do
      records = [
        %{"name" => "John", "age" => "25"},
        %{"name" => "Jane", "age" => "30"},
        # This will fail
        %{"name" => "Bob", "age" => "invalid"}
      ]

      field_mappings = %{
        "name_formatted" => %{
          "source_field" => "name",
          "transformation" => "string"
        },
        "age_number" => %{
          "source_field" => "age",
          "transformation" => "integer"
        }
      }

      result = DataTransformer.transform_records(records, field_mappings)

      assert is_map(result)
      assert result.success_count == 2
      assert result.failure_count == 1
      assert length(result.transformed_records) == 2
      assert length(result.failures) == 1

      # Check transformed records
      transformed_records = result.transformed_records
      john_record = Enum.find(transformed_records, fn r -> r["name_formatted"] == "John" end)
      jane_record = Enum.find(transformed_records, fn r -> r["name_formatted"] == "Jane" end)

      assert john_record["age_number"] == 25
      assert jane_record["age_number"] == 30
    end

    test "handles empty record list" do
      result = DataTransformer.transform_records([], %{})

      assert result.success_count == 0
      assert result.failure_count == 0
      assert result.transformed_records == []
      assert result.failures == []
    end
  end

  describe "apply_business_rules/2" do
    test "applies customer validation rules" do
      record = %{
        "first_name" => "John",
        "email" => "john@example.com",
        "internet_service" => false,
        "phone_service" => true
      }

      business_rules = %{
        "customer_validation" => %{}
      }

      result = DataTransformer.apply_business_rules(record, business_rules)

      assert {:ok, final_record} = result
      # Should add required fields if missing
      assert Map.has_key?(final_record, "first_name")
      assert Map.has_key?(final_record, "last_name")
      assert Map.has_key?(final_record, "email")
    end

    test "applies billing rules" do
      record = %{
        "base_amount" => 100.0
      }

      business_rules = %{
        "billing_validation" => %{}
      }

      result = DataTransformer.apply_business_rules(record, business_rules)

      assert {:ok, final_record} = result
      # Should calculate tax_amount and total_amount
      assert Map.has_key?(final_record, "tax_amount")
      assert Map.has_key?(final_record, "total_amount")
      assert final_record["total_amount"] > final_record["base_amount"]
    end

    test "applies network validation rules" do
      record = %{
        "ip_address" => "192.168.1.1"
      }

      business_rules = %{
        "network_validation" => %{}
      }

      result = DataTransformer.apply_business_rules(record, business_rules)

      assert {:ok, final_record} = result
      # Should validate IP address (in real implementation)
      assert final_record["ip_address"] == "192.168.1.1"
    end

    test "applies compliance rules" do
      record = %{
        "name" => "John Doe",
        "ssn" => "123-45-6789"
      }

      business_rules = %{
        "compliance" => %{}
      }

      result = DataTransformer.apply_business_rules(record, business_rules)

      assert {:ok, final_record} = result
      # Should add audit fields and mask sensitive data
      assert Map.has_key?(final_record, "imported_at")
      assert Map.has_key?(final_record, "data_version")
      assert final_record["ssn"] == "***MASKED***"
    end
  end

  describe "generate_isp_field_mappings/1" do
    test "generates field mappings for legacy customer database" do
      result = DataTransformer.generate_isp_field_mappings("legacy_customer_db")

      assert is_map(result)
      assert Map.has_key?(result, "customer_id")
      assert Map.has_key?(result, "first_name")
      assert Map.has_key?(result, "last_name")
      assert Map.has_key?(result, "email")
      assert Map.has_key?(result, "phone")
      assert Map.has_key?(result, "service_type")

      # Check specific field mappings
      customer_id_mapping = result["customer_id"]
      assert customer_id_mapping["source_field"] == "cust_id"
      assert customer_id_mapping["transformation"] == "string"

      email_mapping = result["email"]
      assert email_mapping["source_field"] == "email_address"
      assert email_mapping["transformation"] == "function:normalize_email"
      assert email_mapping["required"] == true
    end

    test "generates field mappings for billing system" do
      result = DataTransformer.generate_isp_field_mappings("billing_system")

      assert is_map(result)
      assert Map.has_key?(result, "customer_id")
      assert Map.has_key?(result, "billing_cycle")
      assert Map.has_key?(result, "base_amount")
      assert Map.has_key?(result, "tax_rate")

      # Check specific field mappings
      base_amount_mapping = result["base_amount"]
      assert base_amount_mapping["source_field"] == "monthly_fee"
      assert base_amount_mapping["transformation"] == "float"

      tax_rate_mapping = result["tax_rate"]
      assert tax_rate_mapping["transformation"] == "float"
      assert tax_rate_mapping["default"] == 0.08
    end

    test "returns empty mapping for unknown data type" do
      result = DataTransformer.generate_isp_field_mappings("unknown_system")

      assert result == %{}
    end
  end

  describe "edge cases and error handling" do
    test "handles nil record" do
      result = DataTransformer.transform_record(nil, %{})

      assert {:ok, transformed} = result
      assert transformed == %{}
    end

    test "handles empty field mappings" do
      record = %{"name" => "John"}

      result = DataTransformer.transform_record(record, %{})

      assert {:ok, transformed} = result
      assert transformed == %{}
    end

    test "handles invalid transformation function" do
      record = %{"name" => "John"}

      field_mappings = %{
        "name" => %{
          "source_field" => "name",
          "transformation" => "function:nonexistent_function"
        }
      }

      result = DataTransformer.transform_record(record, field_mappings)

      assert {:ok, transformed} = result
      # Failed function should return original value
      assert transformed["name"] == "John"
    end

    test "handles malformed field mapping configuration" do
      record = %{"name" => "John"}

      field_mappings = %{
        "name" => %{
          # Missing source_field
          "transformation" => "string"
        }
      }

      result = DataTransformer.transform_record(record, field_mappings)

      assert {:ok, transformed} = result
      # Should handle gracefully - name will be nil
      assert is_nil(transformed["name"])
    end
  end
end
