defmodule Mcp.Underwriting.Services.MentionParserTest do
  use ExUnit.Case, async: true

  alias Mcp.Underwriting.Services.MentionParser

  describe "parse/1" do
    test "extracts single mention" do
      result = MentionParser.parse("Hey @john.doe check this")
      assert result.mentions == ["john.doe"]
      assert result.plain_text == "Hey @john.doe check this"
    end

    test "extracts multiple mentions" do
      result = MentionParser.parse("@alice and @bob please review")
      assert result.mentions == ["alice", "bob"]
    end

    test "handles no mentions" do
      result = MentionParser.parse("No mentions here")
      assert result.mentions == []
    end

    test "handles email-like @" do
      result = MentionParser.parse("Email me at test@example.com and @admin")
      # Should only get @admin, not email
      assert result.mentions == ["admin"]
    end

    test "deduplicates repeated mentions" do
      result = MentionParser.parse("Hey @john and @john again")
      assert result.mentions == ["john"]
    end
  end

  describe "render_html/2" do
    test "converts mentions to links" do
      content = "Hey @john check this"
      users = [%{username: "john", id: "123", display_name: "John Doe"}]
      html = MentionParser.render_html(content, users)
      assert html =~ ~s(<a href="/users/123")
      assert html =~ "John Doe"
    end

    test "leaves unresolved mentions as-is" do
      content = "Hey @unknown check this"
      users = []
      html = MentionParser.render_html(content, users)
      assert html =~ "@unknown"
      refute html =~ "<a"
    end
  end
end
