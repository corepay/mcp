defmodule Mcp.Underwriting.Tools.AnalyzeDocumentTest do
  use Mcp.DataCase

  alias Mcp.Underwriting.Tools.AnalyzeDocument

  test "analyzes blurry document" do
    [result] = AnalyzeDocument.analyze!("blurry_id.jpg")
    assert result.result =~ "too blurry"
  end

  test "analyzes valid passport" do
    [result] = AnalyzeDocument.analyze!("my_passport.jpg")
    assert result.result =~ "valid Identity Document"
  end

  test "analyzes other document" do
    [result] = AnalyzeDocument.analyze!("other_doc.pdf")
    assert result.result =~ "valid document of type 'Other'"
  end
end
