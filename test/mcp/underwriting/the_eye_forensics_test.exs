defmodule Mcp.Underwriting.TheEyeForensicsTest do
  @moduledoc """
  Verifies the Multimodal Forensics logic of The Eye service.
  """
  use Mcp.DataCase
  alias Mcp.Underwriting.Services.DocumentIntelligence

  setup do
    unique_id = System.unique_integer([:positive])
    schema = "acq_test_forensics_#{unique_id}"
    Mcp.Repo.query!("CREATE SCHEMA IF NOT EXISTS \"#{schema}\"")

    # DDL for document_analyses
    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".document_analyses (
      id uuid PRIMARY KEY,
      status text,
      analysis_type text,
      markdown_content text,
      structured_data jsonb,
      forensics_report jsonb,
      camera_telemetry jsonb,
      provider text,
      merchant_id uuid,
      inserted_at timestamp(6),
      updated_at timestamp(6)
    )")

    {:ok, schema: schema}
  end

  test "detects image manipulation in suspect documents", %{schema: schema} do
    merchant_id = Ecto.UUID.generate()
    path = "/tmp/test_fake_id.png"
    File.write!(path, "dummy_content")

    opts = [
      tenant: schema,
      analysis_type: :multimodal,
      camera_telemetry: %{
        "device" => "iPhone 15 Pro",
        "gps_accuracy" => 10,
        "location" => %{"lat" => 40.7128, "lng" => -74.0060}
      }
    ]

    assert {:ok, analysis} = DocumentIntelligence.analyze(path, merchant_id, opts)

    assert analysis.status == :completed
    assert analysis.analysis_type == :multimodal
    assert analysis.forensics_report["manipulation_detected"] == true
    assert analysis.forensics_report["verdict"] == "suspicious"
    assert analysis.camera_telemetry["verified"] == true

    File.rm!(path)
  end

  test "verifies authentic documents", %{schema: schema} do
    merchant_id = Ecto.UUID.generate()

    opts = [
      tenant: schema,
      analysis_type: :multimodal,
      camera_telemetry: %{
        "device" => "Android Pixel 8",
        # Poor accuracy
        "gps_accuracy" => 80
      }
    ]

    # Note: resolve_file_content treats "binary_data" as local file path if it doesn't match protocols.
    # To fix this in test, I'll write a temp file.
    path = "/tmp/authentic_passport.jpg"
    File.write!(path, "dummy_content")

    assert {:ok, analysis} = DocumentIntelligence.analyze(path, merchant_id, opts)

    assert analysis.forensics_report["manipulation_detected"] == false
    assert analysis.forensics_report["verdict"] == "authentic"
    # gps_accuracy 80 > 50 -> verified should be false in our mock
    assert analysis.camera_telemetry["verified"] == false

    File.rm!(path)
  end
end
