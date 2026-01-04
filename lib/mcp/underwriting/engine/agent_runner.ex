defmodule Mcp.Underwriting.Engine.AgentRunner do
  @moduledoc """
  The interface to the LLM (LangChain / OpenAI).
  Executes a single Agent Blueprint with a given Context and Instruction Set.
  """

  alias Mcp.Ai.{Document, EmbeddingService, LlmUsage, SemanticCache}
  alias Mcp.Telemetry
  alias Mcp.Underwriting.{AgentBlueprint, InstructionSet}
  alias Mcp.Utils.{CircuitBreaker, RateLimiter}

  @doc """
  Runs the agent.
  For v1, this is a mock that returns a static response based on the blueprint name.
  """
  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatOllamaAI
  alias LangChain.Message

  def run(
        %AgentBlueprint{} = blueprint,
        %InstructionSet{} = instructions,
        context \\ %{},
        opts \\ []
      ) do
    if Application.get_env(:mcp, :agent_runner_adapter) == :mock do
      mock_run(blueprint, instructions, context)
    else
      do_run(blueprint, instructions, context, opts)
    end
  end

  defp mock_run(blueprint, _instructions, _context) do
    # Return a dummy response based on blueprint name
    response =
      case blueprint.name do
        "FinancialAnalyst" -> %{"decision" => "approve", "dti" => 0.35, "confidence" => 0.95}
        "ResponseReviewer" -> %{"status" => "approved", "confidence" => 1.0}
        _ -> %{"result" => "mock_response", "confidence" => 1.0}
      end

    {:ok, response}
  end

  defp do_run(blueprint, instructions, context, opts) do
    # Determine initial provider based on blueprint config or opts override
    routing_config = blueprint.routing_config || %{mode: :single, primary_provider: :ollama}

    requested_provider =
      Keyword.get(opts, :provider, routing_config[:primary_provider] || :ollama)

    tenant_id = Keyword.get(opts, :tenant_id, "default")

    # Rate Limit Check
    case RateLimiter.check_limit("tenant:#{tenant_id}", 100) do
      :ok ->
        execute_agent_run(
          blueprint,
          instructions,
          context,
          opts,
          requested_provider,
          routing_config
        )

      {:error, :rate_limit_exceeded} ->
        IO.warn("Rate limit exceeded for tenant #{tenant_id}")
        {:ok, %{"error" => "Rate limit exceeded. Please try again later."}}
    end
  end

  defp execute_agent_run(blueprint, instructions, context, opts, provider, config) do
    start_time = System.monotonic_time(:millisecond)

    {result, usage_stats} =
      execute_with_fallback(
        blueprint,
        instructions,
        context,
        provider,
        config
      )

    latency = System.monotonic_time(:millisecond) - start_time

    # Emit Telemetry
    Telemetry.execute(
      [:ai, :agent, :completion],
      %{
        latency: latency,
        total_tokens: usage_stats[:total_tokens] || 0,
        cost: usage_stats[:cost] || 0
      },
      %{
        blueprint: blueprint.name,
        provider: usage_stats[:provider],
        model: usage_stats[:model],
        cached: Map.get(usage_stats, :cached, false),
        tenant_id: context[:tenant_id]
      }
    )

    if execution_id = Keyword.get(opts, :execution_id) do
      track_usage(execution_id, usage_stats[:provider], usage_stats, latency, opts)
    end

    result
  end

  defp execute_with_fallback(blueprint, instructions, context, provider, config) do
    # Wrap execution with Circuit Breaker
    {result, stats} = execute_with_circuit_breaker(provider, blueprint, instructions, context)

    if should_fallback?(result, provider, config) do
      execute_fallback(
        blueprint,
        instructions,
        context,
        config[:fallback_provider],
        result,
        stats
      )
    else
      {result, stats}
    end
  end

  defp execute_with_circuit_breaker(provider, blueprint, instructions, context) do
    result_tuple =
      CircuitBreaker.execute(provider, fn ->
        execute_provider(provider, blueprint, instructions, context)
      end)

    case result_tuple do
      {:ok, {res, st}} ->
        {res, st}

      {:error, :circuit_open} ->
        {{:ok, %{"error" => "Circuit open for provider #{provider}"}},
         %{provider: provider, model: "unknown", cost: 0}}

      {:error, reason} ->
        {{:ok, %{"error" => "Provider error: #{inspect(reason)}"}},
         %{provider: provider, model: "unknown", cost: 0}}
    end
  end

  defp should_fallback?(result, provider, config) do
    config[:mode] == :fallback &&
      provider == config[:primary_provider] &&
      (low_confidence?(result, config[:min_confidence] || 0.8) || error?(result))
  end

  defp execute_fallback(
         blueprint,
         instructions,
         context,
         fallback_provider,
         _original_result,
         _original_stats
       ) do
    fallback_provider = fallback_provider || :openrouter

    IO.puts("⚠️ Low confidence or error. Falling back to #{fallback_provider}...")

    case execute_with_circuit_breaker(fallback_provider, blueprint, instructions, context) do
      {fb_res, fb_st} ->
        {fb_res, fb_st}

        # If fallback fails too (e.g. circuit open), we get a result from execute_with_circuit_breaker anyway,
        # but if we wanted to revert to original error we could check here.
        # For now, relying on the return value of execute_with_circuit_breaker is safe.
    end
  end

  defp execute_provider(:ollama, blueprint, instructions, context),
    do: run_ollama(blueprint, instructions, context)

  defp execute_provider(:openrouter, blueprint, instructions, context),
    do: run_openrouter(blueprint, instructions, context)

  # Fallback for atom/string mismatch if any
  defp execute_provider("ollama", b, i, c), do: run_ollama(b, i, c)
  defp execute_provider("openrouter", b, i, c), do: run_openrouter(b, i, c)

  defp low_confidence?({:ok, result}, threshold) when is_map(result) do
    confidence = Map.get(result, "confidence", 1.0)
    # If confidence is missing, assume 1.0 (high) unless we want strict enforcement
    # But here we want to fallback if explicitly low
    is_number(confidence) && confidence < threshold
  end

  defp low_confidence?(_, _), do: false

  defp error?({:ok, %{"error" => _}}), do: true
  # defp error?({:error, _}), do: true # Unused
  defp error?(_), do: false

  defp run_ollama(blueprint, instructions, context) do
    IO.puts("🤖 Agent [#{blueprint.name}] is running via Ollama...")
    # 1. Build the prompt
    system_prompt = build_system_prompt(blueprint, instructions)
    user_message = build_user_message(context)

    # 1.5 RAG Injection
    system_prompt =
      if blueprint.knowledge_base_ids && length(blueprint.knowledge_base_ids) > 0 do
        # Build messages from the current conversation for RAG enrichment
        # Messages should include the user query for semantic search
        messages = [
          %{role: :system, content: system_prompt},
          %{role: :user, content: user_message}
        ]

        # Extract tenant_id from context or use default
        tenant_id = Map.get(context, :tenant_id, "default_tenant")

        enrich_prompt_with_rag(
          system_prompt,
          messages,
          blueprint.knowledge_base_ids,
          tenant_id
        )
      else
        system_prompt
      end

    # 2. Select Provider & Model
    # Placeholder for `execution`
    # execution = %{tenant_id: "default_tenant"} # Assuming execution would be passed in
    # {_provider, _model} = select_provider_and_model(blueprint, execution)

    # Get Ollama configuration from Application config (not hardcoded)
    ollama_config = Application.get_env(:mcp, :ollama, [])
    model_name = ollama_config[:model] || System.get_env("OLLAMA_MODEL", "llama3")
    ollama_port = ollama_config[:port] || System.get_env("OLLAMA_PORT")
    ollama_base_url = ollama_config[:base_url] || "http://localhost:#{ollama_port}/api/chat"

    # Check Semantic Cache
    cache_key_prompt = system_prompt <> user_message

    case SemanticCache.get(cache_key_prompt, model_name, :ollama) do
      {:ok, cached_response} ->
        IO.puts("⚡️ Cache Hit for Agent [#{blueprint.name}]")

        usage_stats = %{
          provider: :ollama,
          model: model_name,
          prompt_tokens: 0,
          completion_tokens: 0,
          total_tokens: 0,
          cost: Decimal.new(0),
          cached: true
        }

        {cached_response, usage_stats}

      nil ->
        llm =
          ChatOllamaAI.new!(%{
            model: model_name,
            endpoint: ollama_base_url,
            temperature: 0.1,
            format: "json"
          })

        {:ok, chain} =
          LLMChain.new!(%{llm: llm, verbose: true})
          |> LLMChain.add_message(Message.new_system!(system_prompt))
          |> LLMChain.add_message(Message.new_user!(user_message))
          |> LLMChain.run()

        last_message = chain.last_message
        content = extract_content(last_message)

        usage_stats = %{
          provider: :ollama,
          model: model_name,
          prompt_tokens: 0,
          completion_tokens: 0,
          total_tokens: 0,
          cost: Decimal.new(0)
        }

        result = parse_json(content)

        # Cache the successful result
        case result do
          {:ok, json_result} ->
            SemanticCache.put(cache_key_prompt, model_name, :ollama, json_result)
            {{:ok, json_result}, usage_stats}
        end
    end
  end

  defp run_openrouter(blueprint, instructions, context) do
    IO.puts("🤖 Agent [#{blueprint.name}] is running via OpenRouter...")

    system_prompt = build_system_prompt(blueprint, instructions)
    user_message = build_user_message(context)

    config = Application.get_env(:mcp, :llm, [])
    api_key = config[:openrouter_api_key]
    base_url = config[:openrouter_base_url]
    # Get model from config instead of hardcoding
    model = config[:openrouter_model] || "openai/gpt-3.5-turbo"

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"},
      {"HTTP-Referer", "https://mcp.local"},
      {"X-Title", "MCP Underwriting"}
    ]

    body = %{
      model: model,
      messages: [
        %{role: "system", content: system_prompt},
        %{role: "user", content: user_message}
      ],
      temperature: 0.1,
      response_format: %{type: "json_object"}
    }

    case Req.post("#{base_url}/chat/completions", headers: headers, json: body) do
      {:ok, %{status: 200, body: body}} ->
        choice = List.first(body["choices"])
        content = choice["message"]["content"]
        usage = body["usage"] || %{}

        usage_stats = %{
          provider: :openrouter,
          model: model,
          prompt_tokens: usage["prompt_tokens"] || 0,
          completion_tokens: usage["completion_tokens"] || 0,
          total_tokens: usage["total_tokens"] || 0,
          cost: 0
        }

        {parse_json(content), usage_stats}

      {:ok, %{status: status}} ->
        {{:ok, %{"error" => "OpenRouter request failed: #{status}"}},
         %{provider: :openrouter, model: model}}

      {:error, _reason} ->
        {{:ok, %{"error" => "OpenRouter request failed"}}, %{provider: :openrouter, model: model}}
    end
  end

  defp track_usage(execution_id, provider, stats, latency, opts) do
    tenant_id = Keyword.get(opts, :tenant_id)
    merchant_id = Keyword.get(opts, :merchant_id)
    reseller_id = Keyword.get(opts, :reseller_id)

    LlmUsage
    |> Ash.Changeset.for_create(:create, %{
      execution_id: execution_id,
      provider: provider,
      model: stats[:model],
      prompt_tokens: stats[:prompt_tokens] || 0,
      completion_tokens: stats[:completion_tokens] || 0,
      total_tokens: stats[:total_tokens] || 0,
      cost: stats[:cost],
      latency_ms: latency,
      tenant_id: tenant_id,
      merchant_id: merchant_id,
      reseller_id: reseller_id
    })
    |> Ash.create()
    |> case do
      {:ok, _} -> :ok
      {:error, error} -> IO.warn("Failed to track LLM usage: #{inspect(error)}")
    end
  end

  defp build_system_prompt(blueprint, instructions) do
    """
    #{blueprint.base_prompt}

    INSTRUCTIONS:
    #{instructions.instructions}

    You must respond in valid JSON format.
    Include a "confidence" field (0.0 - 1.0) indicating your certainty in the answer.
    """
  end

  defp build_user_message(context) do
    "Context: #{Jason.encode!(context)}"
  end

  defp extract_content(message) do
    case message.content do
      content when is_binary(content) ->
        content

      parts when is_list(parts) ->
        Enum.map_join(parts, "\n", fn
          %{type: :text, content: text} -> text
          _ -> ""
        end)
    end
  end

  defp enrich_prompt_with_rag(system_prompt, messages, kb_ids, tenant_id) do
    # Get the last user message to use as the search query
    last_message = List.last(messages)

    if last_message.role == :user do
      context = retrieve_rag_context(last_message.content, tenant_id, kb_ids)

      if context != "" do
        system_prompt <> "\n\nRelevant Context from Knowledge Base:\n" <> context
      else
        system_prompt
      end
    else
      system_prompt
    end
  end

  defp retrieve_rag_context(query, tenant_id, kb_ids) do
    with {:ok, embedding} <- EmbeddingService.generate_embedding(query),
         {:ok, documents} <-
           Document.search(embedding,
             tenant_id: tenant_id,
             knowledge_base_ids: kb_ids
           ) do
      Enum.map_join(documents, "\n---\n", & &1.content)
    else
      _ -> ""
    end
  end

  defp parse_json(content) do
    case Jason.decode(content) do
      {:ok, json_result} ->
        {:ok, json_result}

      {:error, _} ->
        extract_json_from_text(content)
    end
  end

  defp extract_json_from_text(content) do
    with [json_match] <- Regex.run(~r/\{.*\}/s, content),
         {:ok, json_result} <- Jason.decode(json_match) do
      {:ok, json_result}
    else
      _ ->
        {:ok, %{"raw_response" => content, "error" => "Failed to parse JSON"}}
    end
  end
end
