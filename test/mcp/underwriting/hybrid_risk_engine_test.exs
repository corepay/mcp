defmodule Mcp.Underwriting.HybridRiskEngineTest do
  use ExUnit.Case, async: true

  alias Mcp.Underwriting.HybridRiskEngine

  # Mock Application struct
  defmodule MockApplication do
    defstruct [:id, :merchant_id, :application_data]
  end

  # Mock MlRiskClient for testing
  defmodule MockMlRiskClient do
    def predict(%{
          business_years: 5,
          monthly_volume: 50_000,
          mcc: 5812,
          owner_count: 2,
          has_website: 1
        }) do
      {:ok, %{score: 85, confidence: 0.92}}
    end

    def predict(%{
          business_years: 1,
          monthly_volume: 10_000,
          mcc: 7995,
          owner_count: 1,
          has_website: 0
        }) do
      {:ok, %{score: 45, confidence: 0.75}}
    end

    def predict(%{
          business_years: 3,
          monthly_volume: 25_000,
          mcc: 5411,
          owner_count: 1,
          has_website: 1
        }) do
      {:ok, %{score: 65, confidence: 0.65}}
    end

    def predict(_features) do
      {:error, :ml_service_unavailable}
    end
  end

  describe "extract_features/1" do
    test "extracts numeric features from application_data" do
      application = %MockApplication{
        application_data: %{
          "business_years" => "5",
          "monthly_volume" => "50000",
          "mcc" => "5812",
          "owner_count" => "2",
          "website" => "https://example.com"
        }
      }

      features = HybridRiskEngine.extract_features(application)

      assert features.business_years == 5
      assert features.monthly_volume == 50_000
      assert features.mcc == 5812
      assert features.owner_count == 2
      assert features.has_website == 1
    end

    test "handles missing website field" do
      application = %MockApplication{
        application_data: %{
          "business_years" => "3",
          "monthly_volume" => "25000",
          "mcc" => "5411",
          "owner_count" => "1"
        }
      }

      features = HybridRiskEngine.extract_features(application)

      assert features.has_website == 0
    end

    test "handles integer values directly" do
      application = %MockApplication{
        application_data: %{
          "business_years" => 5,
          "monthly_volume" => 50_000,
          "mcc" => 5812,
          "owner_count" => 2,
          "website" => "https://example.com"
        }
      }

      features = HybridRiskEngine.extract_features(application)

      assert features.business_years == 5
      assert features.monthly_volume == 50_000
    end
  end

  describe "evaluate/2 with ML predictions" do
    test "combines ML and rule scores with high confidence (>= 0.9)" do
      application = %MockApplication{
        application_data: %{
          "business_years" => "5",
          "monthly_volume" => "50000",
          "mcc" => "5812",
          "owner_count" => "2",
          "website" => "https://example.com"
        }
      }

      vendor_data = %{
        kyb: %{credit_score: 750},
        documents: [{:ok, %{status: :valid}}, {:ok, %{status: :valid}}]
      }

      result = HybridRiskEngine.evaluate(application, vendor_data, MockMlRiskClient)

      # ML: 85, confidence: 0.92 -> ml_weight = 0.8
      # Rules: base 50 + 20 (credit) + 20 (docs) = 90
      # Combined: 85 * 0.8 + 90 * 0.2 = 68 + 18 = 86
      assert result.ml_score == 85
      assert result.rule_score == 90
      assert result.ml_weight == 0.8
      assert result.score == 86
      assert result.recommendation == :approve
      assert is_list(result.reasons)
      assert is_list(result.flags)
    end

    test "combines ML and rule scores with medium-high confidence (>= 0.8)" do
      application = %MockApplication{
        application_data: %{
          "business_years" => "3",
          "monthly_volume" => "25000",
          "mcc" => "5411",
          "owner_count" => "1",
          "website" => "https://example.com"
        }
      }

      vendor_data = %{
        kyb: %{credit_score: 650},
        documents: [{:ok, %{status: :valid}}]
      }

      # Mock ML to return 0.85 confidence
      defmodule MediumHighConfidenceClient do
        def predict(_features) do
          {:ok, %{score: 70, confidence: 0.85}}
        end
      end

      result = HybridRiskEngine.evaluate(application, vendor_data, MediumHighConfidenceClient)

      # ML: 70, confidence: 0.85 -> ml_weight = 0.7
      # Rules: base 50 + 10 (credit) + 10 (docs) = 70
      # Combined: 70 * 0.7 + 70 * 0.3 = 49 + 21 = 70
      assert result.ml_score == 70
      assert result.ml_weight == 0.7
      assert result.score == 70
      assert result.recommendation == :manual_review
    end

    test "combines ML and rule scores with medium confidence (>= 0.7)" do
      application = %MockApplication{
        application_data: %{
          "business_years" => "1",
          "monthly_volume" => "10000",
          "mcc" => "7995",
          "owner_count" => "1"
        }
      }

      vendor_data = %{
        kyb: %{credit_score: 550},
        documents: []
      }

      result = HybridRiskEngine.evaluate(application, vendor_data, MockMlRiskClient)

      # ML: 45, confidence: 0.75 -> ml_weight = 0.6
      # Rules: base 50 + 0 (credit) + 0 (docs) = 50
      # Combined: 45 * 0.6 + 50 * 0.4 = 27 + 20 = 47
      assert result.ml_score == 45
      assert result.rule_score == 50
      assert result.ml_weight == 0.6
      assert result.score == 47
      assert result.recommendation == :reject
    end

    test "uses lower weight for low confidence (< 0.7)" do
      application = %MockApplication{
        application_data: %{
          "business_years" => "3",
          "monthly_volume" => "25000",
          "mcc" => "5411",
          "owner_count" => "1",
          "website" => "https://example.com"
        }
      }

      vendor_data = %{
        kyb: %{credit_score: 600},
        documents: [{:ok, %{status: :valid}}]
      }

      # Mock ML to return low confidence
      defmodule LowConfidenceClient do
        def predict(_features) do
          {:ok, %{score: 80, confidence: 0.65}}
        end
      end

      result = HybridRiskEngine.evaluate(application, vendor_data, LowConfidenceClient)

      # ML: 80, confidence: 0.65 -> ml_weight = 0.5
      # Rules: base 50 + 10 (credit 600) + 10 (docs) = 70
      # Combined: 80 * 0.5 + 70 * 0.5 = 40 + 35 = 75
      assert result.ml_weight == 0.5
      assert result.score == 75
      assert result.recommendation == :manual_review
    end

    test "falls back to rules-only when ML is unavailable" do
      application = %MockApplication{
        application_data: %{
          "business_years" => "unknown",
          "monthly_volume" => "invalid",
          "mcc" => "bad",
          "owner_count" => "1"
        }
      }

      vendor_data = %{
        kyb: %{credit_score: 720},
        documents: [{:ok, %{status: :valid}}]
      }

      result = HybridRiskEngine.evaluate(application, vendor_data, MockMlRiskClient)

      # ML unavailable -> ml_weight = 0.0
      # Rules: base 50 + 20 (credit 720) + 10 (docs) = 80
      # Combined: 0 * 0.0 + 80 * 1.0 = 80
      assert result.ml_score == nil
      assert result.rule_score == 80
      assert result.ml_weight == 0.0
      assert result.score == 80
      assert result.recommendation == :approve
      assert "ML prediction unavailable, using rules only" in result.reasons
    end
  end

  describe "recommendation logic" do
    test "recommends :approve for score >= 80" do
      application = %MockApplication{
        application_data: %{
          "business_years" => "5",
          "monthly_volume" => "50000",
          "mcc" => "5812",
          "owner_count" => "2",
          "website" => "https://example.com"
        }
      }

      vendor_data = %{
        kyb: %{credit_score: 750},
        documents: [{:ok, %{status: :valid}}, {:ok, %{status: :valid}}]
      }

      result = HybridRiskEngine.evaluate(application, vendor_data, MockMlRiskClient)

      assert result.score >= 80
      assert result.recommendation == :approve
    end

    test "recommends :manual_review for score >= 50 and < 80" do
      application = %MockApplication{
        application_data: %{
          "business_years" => "3",
          "monthly_volume" => "25000",
          "mcc" => "5411",
          "owner_count" => "1"
        }
      }

      vendor_data = %{
        kyb: %{credit_score: 600},
        documents: []
      }

      # Mock to get score in manual_review range
      defmodule ManualReviewClient do
        def predict(_features) do
          {:ok, %{score: 60, confidence: 0.8}}
        end
      end

      result = HybridRiskEngine.evaluate(application, vendor_data, ManualReviewClient)

      assert result.score >= 50
      assert result.score < 80
      assert result.recommendation == :manual_review
    end

    test "recommends :reject for score < 50" do
      application = %MockApplication{
        application_data: %{
          "business_years" => "1",
          "monthly_volume" => "10000",
          "mcc" => "7995",
          "owner_count" => "1"
        }
      }

      vendor_data = %{
        kyb: %{credit_score: 450},
        documents: [{:ok, %{status: :invalid}}]
      }

      result = HybridRiskEngine.evaluate(application, vendor_data, MockMlRiskClient)

      assert result.score < 50
      assert result.recommendation == :reject
    end
  end
end
