defmodule Mcp.Underwriting.Atlas.ContextHintsTest do
  use ExUnit.Case, async: true

  alias Mcp.Underwriting.Atlas.ContextHints

  describe "get_hint/2" do
    test "returns hint for document upload step" do
      hint = ContextHints.get_hint(:documents, %{})

      assert hint.message =~ "document"
      assert is_list(hint.suggestions)
      assert length(hint.suggestions) > 0
    end

    test "returns hint for business info step" do
      hint = ContextHints.get_hint(:business_info, %{})

      assert hint.message =~ "business"
      assert hint.icon == "hero-building-office"
    end

    test "returns hint for owners step" do
      hint = ContextHints.get_hint(:owners, %{})

      assert hint.message =~ "owns"
      assert hint.icon == "hero-users"
    end

    test "returns hint for banking step" do
      hint = ContextHints.get_hint(:banking, %{})

      assert hint.message =~ "money"
      assert hint.icon == "hero-banknotes"
    end

    test "returns hint for review step" do
      hint = ContextHints.get_hint(:review, %{})

      assert hint.message =~ "Review"
      assert hint.icon == "hero-check-circle"
    end

    test "includes idle prompt after 30 seconds" do
      hint = ContextHints.get_hint(:business_info, %{idle_seconds: 35})

      assert hint.idle_prompt != nil
      assert hint.idle_prompt =~ "tax documents"
    end

    test "no idle prompt before 30 seconds" do
      hint = ContextHints.get_hint(:business_info, %{idle_seconds: 20})

      assert hint.idle_prompt == nil
    end

    test "returns default hint for unknown step" do
      hint = ContextHints.get_hint(:unknown, %{})

      assert hint.message =~ "help"
      assert is_list(hint.suggestions)
    end
  end

  describe "answer_faq/1" do
    test "answers question about EIN" do
      answer = ContextHints.answer_faq("Where do I find my EIN?")

      assert answer =~ "EIN"
      assert answer =~ "9 digits"
    end

    test "answers question about SSN" do
      answer = ContextHints.answer_faq("Why do you need my SSN?")

      assert answer =~ "identity verification"
      assert answer =~ "encrypted"
    end

    test "answers question about documents" do
      answer = ContextHints.answer_faq("What documents do I need?")

      assert answer =~ "ID"
    end

    test "answers question about approval time" do
      answer = ContextHints.answer_faq("How long does approval take?")

      assert answer =~ "minutes"
    end

    test "answers question about security" do
      answer = ContextHints.answer_faq("Is my data secure?")

      assert answer =~ "encryption"
    end

    test "provides fallback for unknown questions" do
      answer = ContextHints.answer_faq("What is the meaning of life?")

      assert answer =~ "support"
    end
  end
end
