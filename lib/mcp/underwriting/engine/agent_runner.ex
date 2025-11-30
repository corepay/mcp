defmodule Mcp.Underwriting.Engine.AgentRunner do
  @moduledoc """
  The interface to the LLM (LangChain / OpenAI).
  Executes a single Agent Blueprint with a given Context and Instruction Set.
  """

  alias Mcp.Underwriting.AgentBlueprint
  alias Mcp.Underwriting.InstructionSet

  @doc """
  Runs the agent.
  For v1, this is a mock that returns a static response based on the blueprint name.
  """
  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatOllamaAI
  alias LangChain.Message


  def run(%AgentBlueprint{} = blueprint, %InstructionSet{} = instructions, context \\ %{}, opts \\ []) do
    # Determine initial provider based on blueprint config or opts override
    routing_config = blueprint.routing_config || %{mode: :single, primary_provider: :ollama}
    requested_provider = Keyword.get(opts, :provider, routing_config[:primary_provider] || :ollama)
    execution_id = Keyword.get(opts, :execution_id)
    tenant_id = Keyword.get(opts, :tenant_id, "default")
    
    # Rate Limit Check
    case Mcp.Utils.RateLimiter.check_limit("tenant:#{tenant_id}", 100) do
      :ok ->
        start_time = System.monotonic_time(:millisecond)

        {result, usage_stats} = execute_with_fallback(blueprint, instructions, context, requested_provider, routing_config)

        latency = System.monotonic_time(:millisecond) - start_time

        # Emit Telemetry
        Mcp.Telemetry.execute(
          [:ai, :agent, :completion], 
          %{latency: latency, total_tokens: usage_stats[:total_tokens] || 0, cost: usage_stats[:cost] || 0},
          %{
            blueprint: blueprint.name,
            provider: usage_stats[:provider],
            model: usage_stats[:model],
            cached: Map.get(usage_stats, :cached, false),
            tenant_id: context[:tenant_id]
          }
        )

        if execution_id do
          track_usage(execution_id, usage_stats[:provider], usage_stats, latency, opts)
        end

        result

      {:error, :rate_limit_exceeded} ->
        IO.warn("Rate limit exceeded for tenant #{tenant_id}")
        {:ok, %{"error" => "Rate limit exceeded. Please try again later."}}
    end
  end

  defp execute_with_fallback(blueprint, instructions, context, provider, config) do
    # Wrap execution with Circuit Breaker
    result_tuple = Mcp.Utils.CircuitBreaker.execute(provider, fn ->
      execute_provider(provider, blueprint, instructions, context)
    end)

    {result, stats} = case result_tuple do
      {:ok, {res, st}} -> {res, st}
      {:error, :circuit_open} -> 
        {{:ok, %{"error" => "Circuit open for provider #{provider}"}}, %{provider: provider, model: "unknown", cost: 0}}
      {:error, reason} ->
        {{:ok, %{"error" => "Provider error: #{inspect(reason)}"}}, %{provider: provider, model: "unknown", cost: 0}}
    end
    
    # Check if we need fallback
    should_fallback? = 
      config[:mode] == :fallback && 
      provider == config[:primary_provider] &&
      (is_low_confidence?(result, config[:min_confidence] || 0.8) || is_error?(result))

    if should_fallback? do
      fallback_provider = config[:fallback_provider] || :openrouter
      IO.puts("⚠️ Low confidence or error with #{provider}. Falling back to #{fallback_provider}...")
      
      # Also wrap fallback in Circuit Breaker
      fallback_tuple = Mcp.Utils.CircuitBreaker.execute(fallback_provider, fn ->
        execute_provider(fallback_provider, blueprint, instructions, context)
      end)

      case fallback_tuple do
        {:ok, {fb_res, fb_st}} -> {fb_res, fb_st}
        _ -> {result, stats} # Return original failure if fallback also fails
      end
    else
      {result, stats}
    end
  end

  defp execute_provider(:ollama, blueprint, instructions, context), do: run_ollama(blueprint, instructions, context)
  defp execute_provider(:openrouter, blueprint, instructions, context), do: run_openrouter(blueprint, instructions, context)
  # Fallback for atom/string mismatch if any
  defp execute_provider("ollama", b, i, c), do: run_ollama(b, i, c)
  defp execute_provider("openrouter", b, i, c), do: run_openrouter(b, i, c)

  defp is_low_confidence?({:ok, result}, threshold) when is_map(result) do
    confidence = Map.get(result, "confidence", 1.0)
    # If confidence is missing, assume 1.0 (high) unless we want strict enforcement
    # But here we want to fallback if explicitly low
    is_number(confidence) && confidence < threshold
  end
  defp is_low_confidence?(_, _), do: false

  defp is_error?({:ok, %{"error" => _}}), do: true
  # defp is_error?({:error, _}), do: true # Unused
  defp is_error?(_), do: false

  defp run_ollama(blueprint, instructions, context) do
    IO.puts("🤖 Agent [#{blueprint.name}] is running via Ollama...")
    # 1. Build the prompt
    system_prompt = build_system_prompt(blueprint, instructions)
    user_message = build_user_message(context)
    
    # 1.5 RAG Injection
    system_prompt = 
      if blueprint.knowledge_base_ids && length(blueprint.knowledge_base_ids) > 0 do
        # NOTE: `messages`, `execution` are not available in this scope.
        # This code snippet is likely part of a larger change where these variables
        # would be passed into `run_ollama` or derived from `context`.
        # For now, we'll assume `enrich_prompt_with_rag` and `select_provider_and_model`
        # are defined elsewhere or will be added.
        # Placeholder for `messages` and `execution`
        messages = [] # Assuming messages would be derived from context or passed in
        execution = %{tenant_id: "default_tenant"} # Assuming execution would be passed in
        enrich_prompt_with_rag(system_prompt, messages, blueprint.knowledge_base_ids, execution.tenant_id)
      else
        system_prompt
      end

    # 2. Select Provider & Model
    # Placeholder for `execution`
    # execution = %{tenant_id: "default_tenant"} # Assuming execution would be passed in
    # {_provider, _model} = select_provider_and_model(blueprint, execution)
    
    model_name = System.get_env("OLLAMA_MODEL", "llama3")
    ollama_port = System.get_env("OLLAMA_PORT", "42736")
    ollama_base_url = System.get_env("OLLAMA_BASE_URL", "http://localhost:#{ollama_port}/api/chat")

    # Check Semantic Cache
    cache_key_prompt = system_prompt <> user_message
    
    case Mcp.Ai.SemanticCache.get(cache_key_prompt, model_name, :ollama) do
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
        llm = ChatOllamaAI.new!(%{
          model: model_name,
          endpoint: ollama_base_url,
          temperature: 0.1,
          format: "json"
        })

        {:ok, chain} = LLMChain.new!(%{llm: llm, verbose: true})
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
            Mcp.Ai.SemanticCache.put(cache_key_prompt, model_name, :ollama, json_result)
            {{:ok, json_result}, usage_stats}
          other -> 
            {other, usage_stats}
        end
    end
  end

  defp run_openrouter(blueprint, instructions, context) do
    IO.puts("🤖 Agent [#{blueprint.name}] is running via OpenRouter...")

    system_prompt = build_system_prompt(blueprint, instructions)
    user_message = build_user_message(context)

    config = Application.get_env(:mcp, :llm)
    api_key = config[:openrouter_api_key]
    base_url = config[:openrouter_base_url]
    model = "openai/gpt-3.5-turbo" 

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
        {{:ok, %{"error" => "OpenRouter request failed: #{status}"}}, %{provider: :openrouter, model: model}}

      {:error, _reason} ->
        {{:ok, %{"error" => "OpenRouter request failed"}}, %{provider: :openrouter, model: model}}
    end
  end

  defp track_usage(execution_id, provider, stats, latency, opts) do
    tenant_id = Keyword.get(opts, :tenant_id)
    merchant_id = Keyword.get(opts, :merchant_id)
    reseller_id = Keyword.get(opts, :reseller_id)

    Mcp.Ai.LlmUsage
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
      content when is_binary(content) -> content
      parts when is_list(parts) -> 
        Enum.map_join(parts, "\n", fn
          %{type: :text, content: text} -> text
          _ -> ""
        end)
    end
  end

  defp enrich_prompt_with_rag(system_prompt, messages, _kb_ids, _tenant_id) when messages == [], do: system_prompt
  
  defp enrich_prompt_with_rag(system_prompt, messages, _kb_ids, tenant_id) do
    # Get the last user message to use as the search query
    last_message = List.last(messages)
    
    if last_message.role == :user do
      query = last_message.content
      
      # Generate embedding for the query
      case Mcp.Ai.EmbeddingService.generate_embedding(query) do
        {:ok, embedding} ->
          # Search for relevant documents
          # We need to search across all KBs in the list.
          # For now, we'll just search generally and filter by tenant if needed.
          # Ideally, we filter by knowledge_base_id IN list.
          # But our search action currently filters by tenant_id.
          # We should update the search action to support knowledge_base_id filtering.
          # For this iteration, we'll assume the tenant filter is sufficient or we'll skip strict KB filtering
          # and rely on the embedding similarity.
          
          # Actually, let's just use the search action we defined.
          # We need to call it via the code interface.
          
          # TODO: Update Document resource to support filtering by list of KB IDs.
          # For now, we search by tenant.
          
          case Mcp.Ai.Document.search(embedding, tenant_id: tenant_id) do
            {:ok, documents} ->
              context = 
                documents
                |> Enum.map(fn doc -> doc.content end)
                |> Enum.join("\n---\n")
              
              if context != "" do
                system_prompt <> "\n\nRelevant Context from Knowledge Base:\n" <> context
              else
                system_prompt
              end
              
            _ -> system_prompt
          end
          
        _ -> system_prompt
      end
    else
      system_prompt
    end
  end


  defp parse_json(content) do
    case Jason.decode(content) do
      {:ok, json_result} -> {:ok, json_result}
      {:error, _} ->
        case Regex.run(~r/\{.*\}/s, content) do
          [json_match] ->
            case Jason.decode(json_match) do
              {:ok, json_result} -> {:ok, json_result}
              {:error, _} -> {:ok, %{"raw_response" => content, "error" => "Failed to parse JSON"}}
            end
          nil ->
            {:ok, %{"raw_response" => content, "error" => "Failed to parse JSON"}}
        end
    end
  end
end
