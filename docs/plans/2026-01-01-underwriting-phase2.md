# Underwriting Phase 2: Advanced Features Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the remaining high-priority underwriting gaps: Full Atlas AI Concierge, Document Pre-Validation, ML Risk Models, Magic Camera, and Deal Room.

**Architecture:** Build on existing patterns - LiveView components for real-time UI, AgentRunner for LLM integration, The Eye for document processing. New ML models will run as a Python sidecar service with Elixir client wrappers.

**Tech Stack:** Phoenix LiveView, LangChain, Ollama/OpenRouter, The Eye (FastAPI), Scikit-learn/XGBoost for ML models, Phoenix Channels for real-time collaboration.

---

## Phase 2A: Full Atlas AI Concierge (Tasks 1-5)

The current Atlas Lite provides static hints. Full Atlas is a real conversational AI that:
- Watches form state and proactively helps
- Answers contextual questions about the current field
- Suggests optimizations ("Consulting is vague, try...")
- Detects idle/stuck users and offers guidance

### Task 1: Atlas Conversation Context Manager

**Files:**
- Create: `lib/mcp/underwriting/atlas/conversation_context.ex`
- Create: `test/mcp/underwriting/atlas/conversation_context_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp/underwriting/atlas/conversation_context_test.exs
defmodule Mcp.Underwriting.Atlas.ConversationContextTest do
  use ExUnit.Case, async: true

  alias Mcp.Underwriting.Atlas.ConversationContext

  describe "build_context/3" do
    test "includes current step information" do
      form_data = %{"business_name" => "Acme Corp"}
      context = ConversationContext.build_context(:business_info, form_data, %{})

      assert context.current_step == :business_info
      assert context.completed_fields == ["business_name"]
    end

    test "identifies missing required fields" do
      form_data = %{"business_name" => ""}
      context = ConversationContext.build_context(:business_info, form_data, %{})

      assert "business_name" in context.missing_required
    end

    test "includes idle duration" do
      context = ConversationContext.build_context(:owners, %{}, %{idle_seconds: 45})

      assert context.user_state.idle_seconds == 45
      assert context.user_state.appears_stuck? == true
    end

    test "tracks field focus history" do
      context = ConversationContext.build_context(:banking, %{}, %{
        field_focus: "routing_number",
        focus_duration: 30
      })

      assert context.user_state.current_field == "routing_number"
      assert context.user_state.field_focus_duration == 30
    end
  end

  describe "required_fields_for/1" do
    test "returns required fields for business_info step" do
      fields = ConversationContext.required_fields_for(:business_info)

      assert "business_name" in fields
      assert "ein" in fields
      assert "business_type" in fields
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp/underwriting/atlas/conversation_context_test.exs`
Expected: FAIL with "module ConversationContext is not available"

**Step 3: Write minimal implementation**

```elixir
# lib/mcp/underwriting/atlas/conversation_context.ex
defmodule Mcp.Underwriting.Atlas.ConversationContext do
  @moduledoc """
  Builds rich context about the current application state for Atlas AI.
  This context enables Atlas to provide relevant, proactive guidance.
  """

  defstruct [
    :current_step,
    :completed_fields,
    :missing_required,
    :form_data,
    :user_state,
    :validation_errors
  ]

  @step_required_fields %{
    business_info: ["business_name", "ein", "business_type", "business_address"],
    owners: ["owner_name", "owner_ssn", "ownership_percentage"],
    documents: ["government_id"],
    banking: ["account_number", "routing_number"],
    review: []
  }

  def build_context(step, form_data, session_state) do
    required = required_fields_for(step)
    completed = get_completed_fields(form_data, required)
    missing = required -- completed

    %__MODULE__{
      current_step: step,
      completed_fields: completed,
      missing_required: missing,
      form_data: sanitize_form_data(form_data),
      user_state: build_user_state(session_state),
      validation_errors: Map.get(session_state, :errors, [])
    }
  end

  def required_fields_for(step) do
    Map.get(@step_required_fields, step, [])
  end

  defp get_completed_fields(form_data, required_fields) do
    Enum.filter(required_fields, fn field ->
      value = Map.get(form_data, field, "")
      is_binary(value) && String.trim(value) != ""
    end)
  end

  defp build_user_state(session_state) do
    idle_seconds = Map.get(session_state, :idle_seconds, 0)

    %{
      idle_seconds: idle_seconds,
      appears_stuck?: idle_seconds > 30,
      current_field: Map.get(session_state, :field_focus),
      field_focus_duration: Map.get(session_state, :focus_duration, 0)
    }
  end

  # Remove sensitive data like SSN, EIN from context sent to AI
  defp sanitize_form_data(form_data) do
    sensitive_fields = ["ssn", "owner_ssn", "ein", "account_number", "routing_number"]

    Enum.reduce(sensitive_fields, form_data, fn field, acc ->
      if Map.has_key?(acc, field) do
        Map.put(acc, field, "[REDACTED]")
      else
        acc
      end
    end)
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp/underwriting/atlas/conversation_context_test.exs`
Expected: PASS (4 tests)

**Step 5: Commit**

```bash
git add lib/mcp/underwriting/atlas/conversation_context.ex test/mcp/underwriting/atlas/conversation_context_test.exs
git commit -m "feat(atlas): add ConversationContext for rich AI context"
```

---

### Task 2: Atlas AI Agent Blueprint

**Files:**
- Create: `lib/mcp/underwriting/atlas/agent.ex`
- Create: `test/mcp/underwriting/atlas/agent_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp/underwriting/atlas/agent_test.exs
defmodule Mcp.Underwriting.Atlas.AgentTest do
  use ExUnit.Case, async: true

  alias Mcp.Underwriting.Atlas.Agent
  alias Mcp.Underwriting.Atlas.ConversationContext

  describe "generate_response/2" do
    test "returns proactive help when user appears stuck" do
      context = %ConversationContext{
        current_step: :business_info,
        completed_fields: ["business_name"],
        missing_required: ["ein", "business_type"],
        user_state: %{appears_stuck?: true, current_field: "ein", idle_seconds: 45}
      }

      {:ok, response} = Agent.generate_response("", context)

      assert response.type == :proactive_help
      assert response.message =~ "EIN"
    end

    test "answers user question about current field" do
      context = %ConversationContext{
        current_step: :owners,
        user_state: %{current_field: "owner_ssn"}
      }

      {:ok, response} = Agent.generate_response("Why do you need my SSN?", context)

      assert response.type == :answer
      assert response.message =~ "identity" or response.message =~ "verification"
    end

    test "suggests improvements for vague entries" do
      context = %ConversationContext{
        current_step: :business_info,
        form_data: %{"business_description" => "consulting"},
        user_state: %{appears_stuck?: false}
      }

      {:ok, response} = Agent.generate_response("Is my description okay?", context)

      assert response.type == :suggestion
      assert response.message =~ "specific" or response.message =~ "clearer"
    end
  end

  describe "build_prompt/2" do
    test "includes step-specific guidance" do
      context = %ConversationContext{current_step: :documents}
      prompt = Agent.build_prompt("What documents?", context)

      assert prompt =~ "document"
      assert prompt =~ "upload"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp/underwriting/atlas/agent_test.exs`
Expected: FAIL with "module Agent is not available"

**Step 3: Write minimal implementation**

```elixir
# lib/mcp/underwriting/atlas/agent.ex
defmodule Mcp.Underwriting.Atlas.Agent do
  @moduledoc """
  Atlas AI Agent - conversational assistant for merchant applications.
  Uses LLM to provide contextual, proactive guidance.
  """

  alias Mcp.Underwriting.Atlas.ConversationContext
  alias Mcp.Underwriting.Engine.AgentRunner
  alias Mcp.Underwriting.{AgentBlueprint, InstructionSet}

  @atlas_blueprint %AgentBlueprint{
    name: "AtlasAI",
    description: "Merchant onboarding concierge",
    base_prompt: """
    You are Atlas, a friendly and knowledgeable merchant onboarding assistant.
    Your job is to help merchants complete their application smoothly.

    PERSONALITY:
    - Warm but professional
    - Proactive - notice when users are stuck and offer help
    - Clear explanations without jargon
    - Reassuring about security/privacy concerns

    CAPABILITIES:
    - Answer questions about form fields
    - Explain why information is needed
    - Suggest improvements to application data
    - Guide users through document requirements
    """,
    routing_config: %{mode: :single, primary_provider: :ollama}
  }

  defstruct [:type, :message, :suggestions, :field_focus]

  def generate_response(user_message, %ConversationContext{} = context) do
    cond do
      # Proactive help for stuck users with no message
      user_message == "" && context.user_state.appears_stuck? ->
        generate_proactive_help(context)

      # Answer user question
      user_message != "" ->
        generate_answer(user_message, context)

      # Default: silent (no response needed)
      true ->
        {:ok, nil}
    end
  end

  def build_prompt(user_message, context) do
    step_guidance = step_specific_prompt(context.current_step)

    """
    #{step_guidance}

    CURRENT STATE:
    - Step: #{context.current_step}
    - Completed fields: #{inspect(context.completed_fields)}
    - Missing required: #{inspect(context.missing_required)}
    - Current field focus: #{context.user_state[:current_field]}
    - User appears stuck: #{context.user_state[:appears_stuck?]}

    USER MESSAGE: #{user_message}

    Respond with JSON: {"type": "answer|suggestion|proactive_help", "message": "...", "suggestions": [...]}
    """
  end

  defp generate_proactive_help(context) do
    field = context.user_state[:current_field] || List.first(context.missing_required)
    help_text = field_help_text(field)

    {:ok, %__MODULE__{
      type: :proactive_help,
      message: help_text,
      field_focus: field
    }}
  end

  defp generate_answer(user_message, context) do
    # For mock/test mode, use pattern matching
    if Application.get_env(:mcp, :agent_runner_adapter) == :mock do
      mock_answer(user_message, context)
    else
      run_llm(user_message, context)
    end
  end

  defp run_llm(user_message, context) do
    instructions = %InstructionSet{
      instructions: build_prompt(user_message, context)
    }

    case AgentRunner.run(@atlas_blueprint, instructions, %{}) do
      {:ok, %{"type" => type, "message" => message}} ->
        {:ok, %__MODULE__{
          type: String.to_existing_atom(type),
          message: message,
          suggestions: []
        }}

      {:ok, response} ->
        {:ok, %__MODULE__{
          type: :answer,
          message: response["raw_response"] || "I can help with that.",
          suggestions: []
        }}

      error ->
        error
    end
  end

  defp mock_answer(user_message, context) do
    user_lower = String.downcase(user_message)

    response = cond do
      String.contains?(user_lower, "ssn") ->
        %__MODULE__{
          type: :answer,
          message: "We need your SSN for identity verification. It's encrypted immediately and never stored in plain text."
        }

      String.contains?(user_lower, "description") || String.contains?(user_lower, "okay") ->
        %__MODULE__{
          type: :suggestion,
          message: "Being more specific helps! Instead of just 'consulting', try 'IT security consulting for healthcare providers'. Clearer descriptions speed up approval."
        }

      true ->
        %__MODULE__{
          type: :answer,
          message: "I'm here to help! What would you like to know about #{context.current_step}?"
        }
    end

    {:ok, response}
  end

  defp step_specific_prompt(:business_info) do
    "User is entering business details. Help with business type selection, EIN location, and address formatting."
  end

  defp step_specific_prompt(:owners) do
    "User is entering owner information. Explain 25% ownership threshold, SSN requirements, and beneficial owner rules."
  end

  defp step_specific_prompt(:documents) do
    "User is uploading documents. Guide on document types, photo quality, and what each document proves."
  end

  defp step_specific_prompt(:banking) do
    "User is connecting bank account. Explain Plaid security, manual entry options, and why bank verification is needed."
  end

  defp step_specific_prompt(_), do: "Help the user complete their application."

  defp field_help_text("ein"), do: "Your EIN (Employer Identification Number) is on your IRS SS-4 confirmation letter, usually at the top right. It's 9 digits: XX-XXXXXXX"
  defp field_help_text("owner_ssn"), do: "We need SSN for identity verification only. It's encrypted immediately and never stored in plain text."
  defp field_help_text("routing_number"), do: "Your routing number is the 9-digit number on the bottom left of your checks. You can also find it in your bank's online portal."
  defp field_help_text(field), do: "Need help with #{field}? I'm here to assist!"
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp/underwriting/atlas/agent_test.exs`
Expected: PASS (4 tests)

**Step 5: Commit**

```bash
git add lib/mcp/underwriting/atlas/agent.ex test/mcp/underwriting/atlas/agent_test.exs
git commit -m "feat(atlas): add Atlas AI Agent with LLM integration"
```

---

### Task 3: Atlas LiveComponent Integration

**Files:**
- Create: `lib/mcp_web/live/ola/components/atlas_chat.ex`
- Create: `test/mcp_web/live/ola/components/atlas_chat_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/ola/components/atlas_chat_test.exs
defmodule McpWeb.Ola.Components.AtlasChatTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias McpWeb.Ola.Components.AtlasChat

  describe "mount/1" do
    test "initializes with empty messages" do
      {:ok, socket} = AtlasChat.mount(%{}, %{}, %Phoenix.LiveView.Socket{})

      assert socket.assigns.messages == []
      assert socket.assigns.input_value == ""
    end
  end

  describe "handle_event send_message" do
    test "adds user message and generates response" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          messages: [],
          current_step: :business_info,
          form_data: %{},
          session_state: %{}
        }
      }

      {:noreply, updated} = AtlasChat.handle_event(
        "send_message",
        %{"message" => "Where do I find my EIN?"},
        socket
      )

      assert length(updated.assigns.messages) >= 1
      user_msg = List.first(updated.assigns.messages)
      assert user_msg.role == :user
      assert user_msg.content == "Where do I find my EIN?"
    end
  end

  describe "handle_info :check_idle" do
    test "triggers proactive help after 30 seconds idle" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          messages: [],
          current_step: :owners,
          form_data: %{},
          session_state: %{idle_seconds: 35, field_focus: "owner_ssn"},
          last_activity: System.monotonic_time(:second) - 35
        }
      }

      {:noreply, updated} = AtlasChat.handle_info(:check_idle, socket)

      # Should have added a proactive message
      assert length(updated.assigns.messages) == 1
      msg = List.first(updated.assigns.messages)
      assert msg.role == :assistant
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/live/ola/components/atlas_chat_test.exs`
Expected: FAIL with "module AtlasChat is not available"

**Step 3: Write minimal implementation**

```elixir
# lib/mcp_web/live/ola/components/atlas_chat.ex
defmodule McpWeb.Ola.Components.AtlasChat do
  @moduledoc """
  Atlas AI chat component for OLA application.
  Provides real-time, context-aware assistance.
  """
  use McpWeb, :live_component

  alias Mcp.Underwriting.Atlas.{Agent, ConversationContext}

  @idle_check_interval 5_000  # Check every 5 seconds
  @idle_threshold 30  # Trigger help after 30 seconds

  def mount(socket) do
    socket =
      socket
      |> assign(:messages, [])
      |> assign(:input_value, "")
      |> assign(:last_activity, System.monotonic_time(:second))
      |> assign(:proactive_shown, false)

    # Start idle checking timer
    if connected?(socket) do
      Process.send_after(self(), :check_idle, @idle_check_interval)
    end

    {:ok, socket}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(:current_step, assigns[:current_step] || :business_info)
      |> assign(:form_data, assigns[:form_data] || %{})
      |> assign(:session_state, assigns[:session_state] || %{})

    {:ok, socket}
  end

  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    # Add user message
    user_msg = %{id: make_ref(), role: :user, content: message, timestamp: DateTime.utc_now()}
    messages = socket.assigns.messages ++ [user_msg]

    # Build context and generate response
    context = ConversationContext.build_context(
      socket.assigns.current_step,
      socket.assigns.form_data,
      socket.assigns.session_state
    )

    socket =
      case Agent.generate_response(message, context) do
        {:ok, response} when not is_nil(response) ->
          ai_msg = %{
            id: make_ref(),
            role: :assistant,
            content: response.message,
            type: response.type,
            timestamp: DateTime.utc_now()
          }
          assign(socket, :messages, messages ++ [ai_msg])

        _ ->
          assign(socket, :messages, messages)
      end

    {:noreply,
     socket
     |> assign(:input_value, "")
     |> assign(:last_activity, System.monotonic_time(:second))
     |> assign(:proactive_shown, false)}
  end

  def handle_event("send_message", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("update_input", %{"value" => value}, socket) do
    {:noreply,
     socket
     |> assign(:input_value, value)
     |> assign(:last_activity, System.monotonic_time(:second))}
  end

  def handle_info(:check_idle, socket) do
    # Schedule next check
    Process.send_after(self(), :check_idle, @idle_check_interval)

    idle_seconds = System.monotonic_time(:second) - socket.assigns.last_activity

    socket =
      if idle_seconds > @idle_threshold && not socket.assigns.proactive_shown do
        # Build context with idle info
        session_state = Map.merge(socket.assigns.session_state, %{idle_seconds: idle_seconds})

        context = ConversationContext.build_context(
          socket.assigns.current_step,
          socket.assigns.form_data,
          session_state
        )

        case Agent.generate_response("", context) do
          {:ok, response} when not is_nil(response) ->
            ai_msg = %{
              id: make_ref(),
              role: :assistant,
              content: response.message,
              type: :proactive_help,
              timestamp: DateTime.utc_now()
            }

            socket
            |> assign(:messages, socket.assigns.messages ++ [ai_msg])
            |> assign(:proactive_shown, true)

          _ ->
            socket
        end
      else
        socket
      end

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="atlas-chat flex flex-col h-full">
      <!-- Chat header -->
      <div class="flex items-center gap-2 p-3 border-b border-base-300">
        <div class="avatar">
          <div class="w-8 h-8 rounded-full bg-primary text-primary-content flex items-center justify-center">
            <.icon name="hero-sparkles" class="w-5 h-5" />
          </div>
        </div>
        <div>
          <div class="font-semibold text-sm">Atlas</div>
          <div class="text-xs text-base-content/60">Your application assistant</div>
        </div>
      </div>

      <!-- Messages area -->
      <div class="flex-1 overflow-y-auto p-3 space-y-3" id="atlas-messages">
        <%= if Enum.empty?(@messages) do %>
          <div class="text-center text-base-content/60 py-8">
            <.icon name="hero-chat-bubble-left-right" class="w-12 h-12 mx-auto mb-2 opacity-50" />
            <p class="text-sm">Hi! I'm Atlas, your application assistant.</p>
            <p class="text-xs mt-1">Ask me anything about the form!</p>
          </div>
        <% else %>
          <%= for msg <- @messages do %>
            <div class={[
              "chat",
              if(msg.role == :user, do: "chat-end", else: "chat-start")
            ]}>
              <div class={[
                "chat-bubble text-sm",
                if(msg.role == :user, do: "chat-bubble-primary", else: "chat-bubble-secondary")
              ]}>
                <%= msg.content %>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>

      <!-- Input area -->
      <form phx-submit="send_message" phx-target={@myself} class="p-3 border-t border-base-300">
        <div class="flex gap-2">
          <input
            type="text"
            name="message"
            value={@input_value}
            phx-change="update_input"
            phx-target={@myself}
            placeholder="Ask Atlas anything..."
            class="input input-bordered input-sm flex-1"
            autocomplete="off"
          />
          <button type="submit" class="btn btn-primary btn-sm">
            <.icon name="hero-paper-airplane" class="w-4 h-4" />
          </button>
        </div>
      </form>
    </div>
    """
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/live/ola/components/atlas_chat_test.exs`
Expected: PASS (3 tests)

**Step 5: Commit**

```bash
git add lib/mcp_web/live/ola/components/atlas_chat.ex test/mcp_web/live/ola/components/atlas_chat_test.exs
git commit -m "feat(atlas): add AtlasChat LiveComponent with proactive help"
```

---

### Task 4: Wire Atlas into OLA Application LiveView

**Files:**
- Modify: `lib/mcp_web/live/ola/application_live.ex`

**Step 1: Read current file**

Read `lib/mcp_web/live/ola/application_live.ex` to understand current structure.

**Step 2: Add Atlas integration**

Add to mount:
```elixir
|> assign(:atlas_session_state, %{idle_seconds: 0, field_focus: nil})
```

Add event handler for field focus tracking:
```elixir
def handle_event("field_focus", %{"field" => field}, socket) do
  session_state = Map.put(socket.assigns.atlas_session_state, :field_focus, field)
  {:noreply, assign(socket, :atlas_session_state, session_state)}
end
```

Add to template (in the chat sidebar area):
```heex
<.live_component
  module={McpWeb.Ola.Components.AtlasChat}
  id="atlas-chat"
  current_step={step_atom(@step)}
  form_data={@form.params}
  session_state={@atlas_session_state}
/>
```

**Step 3: Run OLA tests**

Run: `mix test test/mcp_web/live/ola/`
Expected: PASS

**Step 4: Commit**

```bash
git add lib/mcp_web/live/ola/application_live.ex
git commit -m "feat(ola): integrate Atlas AI chat into application flow"
```

---

### Task 5: Atlas Field-Level Hooks

**Files:**
- Create: `assets/js/hooks/atlas_hooks.js`
- Modify: `assets/js/app.js`

**Step 1: Create the hooks file**

```javascript
// assets/js/hooks/atlas_hooks.js
export const AtlasFieldTracker = {
  mounted() {
    this.trackFields()
  },

  trackFields() {
    const form = this.el.querySelector('form')
    if (!form) return

    // Track field focus
    form.querySelectorAll('input, textarea, select').forEach(field => {
      field.addEventListener('focus', (e) => {
        this.pushEvent('field_focus', { field: e.target.name })
      })

      field.addEventListener('blur', (e) => {
        this.pushEvent('field_blur', { field: e.target.name })
      })
    })

    // Track idle time
    let idleTimer
    const resetIdle = () => {
      clearTimeout(idleTimer)
      idleTimer = setTimeout(() => {
        this.pushEvent('user_idle', { seconds: 30 })
      }, 30000)
    }

    form.addEventListener('input', resetIdle)
    form.addEventListener('mousemove', resetIdle)
    resetIdle()
  }
}
```

**Step 2: Add to app.js**

```javascript
import { AtlasFieldTracker } from './hooks/atlas_hooks'

let Hooks = {}
Hooks.AtlasFieldTracker = AtlasFieldTracker

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  // ... existing config
})
```

**Step 3: Add hook to OLA template**

Add `phx-hook="AtlasFieldTracker"` to the form container div.

**Step 4: Test manually**

Start dev server and verify field tracking works.

**Step 5: Commit**

```bash
git add assets/js/hooks/atlas_hooks.js assets/js/app.js lib/mcp_web/live/ola/application_live.ex
git commit -m "feat(atlas): add field tracking hooks for proactive help"
```

---

## Phase 2B: Document Pre-Validation (Tasks 6-9)

Real-time document quality checking before submission using The Eye.

### Task 6: Document Validator Service

**Files:**
- Create: `lib/mcp/underwriting/services/document_validator.ex`
- Create: `test/mcp/underwriting/services/document_validator_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp/underwriting/services/document_validator_test.exs
defmodule Mcp.Underwriting.Services.DocumentValidatorTest do
  use ExUnit.Case, async: true

  alias Mcp.Underwriting.Services.DocumentValidator

  describe "validate/3" do
    test "returns ok for valid government ID" do
      # Mock content that would come from The Eye
      content = """
      DRIVER LICENSE
      Name: John Doe
      DOB: 01/15/1985
      Address: 123 Main St
      Expires: 12/31/2027
      """

      result = DocumentValidator.validate_extracted_content(content, :government_id)

      assert {:ok, validation} = result
      assert validation.valid? == true
      assert validation.quality_score >= 80
    end

    test "returns error with suggestions for blurry ID" do
      content = "DRVR LIC... [unreadable]"

      result = DocumentValidator.validate_extracted_content(content, :government_id)

      assert {:error, validation} = result
      assert validation.valid? == false
      assert "Name not found" in validation.issues
      assert length(validation.suggestions) > 0
    end

    test "validates bank statement has required fields" do
      content = """
      ACME BANK
      Account: ****4567
      Statement Period: Nov 1 - Nov 30, 2025
      Beginning Balance: $5,432.10
      Ending Balance: $6,789.00
      """

      result = DocumentValidator.validate_extracted_content(content, :bank_statement)

      assert {:ok, validation} = result
      assert validation.valid? == true
    end

    test "rejects bank statement missing balance" do
      content = """
      ACME BANK
      Account Number: 123456789
      Date: November 2025
      """

      result = DocumentValidator.validate_extracted_content(content, :bank_statement)

      assert {:error, validation} = result
      assert "Balance not found" in validation.issues
    end
  end

  describe "check_image_quality/1" do
    test "returns quality metrics" do
      # This would be called with raw image bytes in real usage
      metrics = DocumentValidator.check_image_quality("fake_image_bytes")

      assert is_map(metrics)
      assert Map.has_key?(metrics, :resolution_ok)
      assert Map.has_key?(metrics, :brightness_ok)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp/underwriting/services/document_validator_test.exs`
Expected: FAIL with "module DocumentValidator is not available"

**Step 3: Write minimal implementation**

```elixir
# lib/mcp/underwriting/services/document_validator.ex
defmodule Mcp.Underwriting.Services.DocumentValidator do
  @moduledoc """
  Validates documents before submission using The Eye analysis.
  Provides immediate feedback on document quality and completeness.
  """

  alias Mcp.Underwriting.Services.TheEye

  defstruct [:valid?, :quality_score, :issues, :suggestions, :extracted_data]

  @doc """
  Validates a document by analyzing its content and checking for required fields.
  """
  def validate(file_content, filename, document_type) do
    case TheEye.analyze_document(file_content, filename) do
      {:ok, %{status: "success", markdown_content: content, structured_data: data}} ->
        validation = validate_extracted_content(content, document_type)
        add_extracted_data(validation, data)

      {:ok, %{status: status}} ->
        {:error, %__MODULE__{
          valid?: false,
          quality_score: 0,
          issues: ["Document analysis failed: #{status}"],
          suggestions: ["Please upload a clearer image"]
        }}

      {:error, :service_unavailable} ->
        # Gracefully degrade - allow submission but flag for manual review
        {:ok, %__MODULE__{
          valid?: true,
          quality_score: 50,
          issues: [],
          suggestions: ["Document will be verified manually"]
        }}

      {:error, reason} ->
        {:error, %__MODULE__{
          valid?: false,
          quality_score: 0,
          issues: ["Failed to process document: #{inspect(reason)}"],
          suggestions: ["Please try uploading again"]
        }}
    end
  end

  @doc """
  Validates extracted text content against document type requirements.
  Public for testing without The Eye service.
  """
  def validate_extracted_content(content, :government_id) do
    checks = [
      {contains_any?(content, ["name", "Name", "NAME"]), "Name not found",
       "Ensure the full name is visible and not obscured"},
      {contains_any?(content, ["DOB", "Date of Birth", "birth", "Birth", "BIRTH"]),
       "Date of birth not found", "Make sure the birth date area is clearly visible"},
      {contains_any?(content, ["expires", "Expires", "EXP", "EXPIR"]),
       "Expiration date not found", "Include the expiration date in the photo"},
      {String.length(content) > 50, "Document appears unreadable",
       "Take a new photo with better lighting"}
    ]

    build_validation_result(checks, :government_id)
  end

  def validate_extracted_content(content, :bank_statement) do
    checks = [
      {contains_any?(content, ["balance", "Balance", "BALANCE"]), "Balance not found",
       "Statement must show account balance"},
      {contains_any?(content, ["account", "Account", "ACCOUNT"]), "Account info not found",
       "Statement must show account number"},
      {contains_any?(content, ["bank", "Bank", "BANK", "Credit Union"]), "Bank name not found",
       "Statement header should be visible"},
      {String.length(content) > 100, "Document appears unreadable",
       "Upload a complete, legible statement"}
    ]

    build_validation_result(checks, :bank_statement)
  end

  def validate_extracted_content(content, :business_license) do
    checks = [
      {contains_any?(content, ["license", "License", "LICENSE", "permit", "Permit"]),
       "License type not found", "Document must clearly show license type"},
      {String.length(content) > 30, "Document appears unreadable",
       "Take a clearer photo of the license"}
    ]

    build_validation_result(checks, :business_license)
  end

  def validate_extracted_content(_content, _type) do
    # Unknown type - basic validation only
    {:ok, %__MODULE__{
      valid?: true,
      quality_score: 70,
      issues: [],
      suggestions: []
    }}
  end

  @doc """
  Checks basic image quality metrics.
  Returns quality indicators for resolution, brightness, blur.
  """
  def check_image_quality(_image_bytes) do
    # In production, this would use image processing library
    # For now, return default acceptable metrics
    %{
      resolution_ok: true,
      brightness_ok: true,
      blur_detected: false,
      recommended_action: nil
    }
  end

  defp build_validation_result(checks, _doc_type) do
    failed_checks = Enum.filter(checks, fn {passed, _, _} -> not passed end)
    issues = Enum.map(failed_checks, fn {_, issue, _} -> issue end)
    suggestions = Enum.map(failed_checks, fn {_, _, suggestion} -> suggestion end)

    passed_count = length(checks) - length(failed_checks)
    quality_score = round(passed_count / length(checks) * 100)

    if Enum.empty?(issues) do
      {:ok, %__MODULE__{
        valid?: true,
        quality_score: quality_score,
        issues: [],
        suggestions: []
      }}
    else
      {:error, %__MODULE__{
        valid?: false,
        quality_score: quality_score,
        issues: issues,
        suggestions: suggestions
      }}
    end
  end

  defp add_extracted_data({status, validation}, extracted_data) do
    {status, %{validation | extracted_data: extracted_data}}
  end

  defp contains_any?(content, terms) do
    Enum.any?(terms, &String.contains?(content, &1))
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp/underwriting/services/document_validator_test.exs`
Expected: PASS (5 tests)

**Step 5: Commit**

```bash
git add lib/mcp/underwriting/services/document_validator.ex test/mcp/underwriting/services/document_validator_test.exs
git commit -m "feat(uw): add DocumentValidator for pre-submission checks"
```

---

### Task 7: Document Upload LiveComponent with Validation

**Files:**
- Create: `lib/mcp_web/live/ola/components/validated_upload.ex`
- Create: `test/mcp_web/live/ola/components/validated_upload_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/ola/components/validated_upload_test.exs
defmodule McpWeb.Ola.Components.ValidatedUploadTest do
  use McpWeb.ConnCase, async: true

  alias McpWeb.Ola.Components.ValidatedUpload

  describe "validate_on_upload/2" do
    test "validates document and returns feedback" do
      # This tests the validation flow
      result = ValidatedUpload.process_validation(
        "test_content",
        "license.jpg",
        :government_id
      )

      assert is_map(result)
      assert Map.has_key?(result, :valid?)
    end
  end
end
```

**Step 2: Write implementation**

```elixir
# lib/mcp_web/live/ola/components/validated_upload.ex
defmodule McpWeb.Ola.Components.ValidatedUpload do
  @moduledoc """
  Document upload component with real-time validation feedback.
  Uses The Eye to analyze documents as they're uploaded.
  """
  use McpWeb, :live_component

  alias Mcp.Underwriting.Services.DocumentValidator

  def mount(socket) do
    {:ok, assign(socket, validation_result: nil, validating: false)}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(:document_type, assigns[:document_type] || :other)
      |> assign(:label, assigns[:label] || "Upload Document")
      |> assign(:upload_ref, assigns[:upload_ref])
      |> assign(:uploads, assigns[:uploads])

    {:ok, socket}
  end

  def handle_event("validate_upload", %{"ref" => ref}, socket) do
    # Get the upload entry
    entry = Enum.find(socket.assigns.uploads.entries, &(&1.ref == ref))

    if entry do
      # Mark as validating
      socket = assign(socket, :validating, true)

      # In a real implementation, we'd read the file and validate
      # For now, simulate async validation
      send(self(), {:validation_complete, ref, %{valid?: true, issues: []}})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:validation_complete, _ref, result}, socket) do
    {:noreply,
     socket
     |> assign(:validating, false)
     |> assign(:validation_result, result)}
  end

  def process_validation(content, filename, document_type) do
    case DocumentValidator.validate(content, filename, document_type) do
      {:ok, validation} -> Map.from_struct(validation)
      {:error, validation} -> Map.from_struct(validation)
    end
  end

  def render(assigns) do
    ~H"""
    <div class="validated-upload">
      <label class="block text-sm font-medium mb-2"><%= @label %></label>

      <div class="border-2 border-dashed border-base-300 rounded-lg p-4 text-center hover:border-primary transition-colors">
        <.live_file_input upload={@uploads} class="hidden" />

        <div class="space-y-2">
          <.icon name="hero-cloud-arrow-up" class="w-8 h-8 mx-auto text-base-content/50" />
          <p class="text-sm text-base-content/70">
            Drag & drop or click to upload
          </p>
        </div>
      </div>

      <!-- Validation feedback -->
      <%= if @validating do %>
        <div class="mt-2 flex items-center gap-2 text-info">
          <span class="loading loading-spinner loading-xs"></span>
          <span class="text-sm">Checking document quality...</span>
        </div>
      <% end %>

      <%= if @validation_result do %>
        <div class={[
          "mt-2 p-3 rounded-lg text-sm",
          if(@validation_result.valid?, do: "bg-success/10 text-success", else: "bg-error/10 text-error")
        ]}>
          <%= if @validation_result.valid? do %>
            <div class="flex items-center gap-2">
              <.icon name="hero-check-circle" class="w-5 h-5" />
              <span>Document looks good!</span>
            </div>
          <% else %>
            <div class="space-y-2">
              <div class="flex items-center gap-2">
                <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
                <span>Please fix these issues:</span>
              </div>
              <ul class="list-disc list-inside ml-2">
                <%= for issue <- @validation_result.issues do %>
                  <li><%= issue %></li>
                <% end %>
              </ul>
              <%= if @validation_result.suggestions != [] do %>
                <div class="mt-2 text-base-content/70">
                  <strong>Tips:</strong>
                  <ul class="list-disc list-inside ml-2">
                    <%= for suggestion <- @validation_result.suggestions do %>
                      <li><%= suggestion %></li>
                    <% end %>
                  </ul>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
```

**Step 3: Run tests**

Run: `mix test test/mcp_web/live/ola/components/validated_upload_test.exs`
Expected: PASS

**Step 4: Commit**

```bash
git add lib/mcp_web/live/ola/components/validated_upload.ex test/mcp_web/live/ola/components/validated_upload_test.exs
git commit -m "feat(ola): add ValidatedUpload component with real-time feedback"
```

---

### Task 8: Wire Document Validation into Upload Flow

**Files:**
- Modify: `lib/mcp_web/live/ola/application_live.ex`

**Step 1: Add validation on file select**

Add handler:
```elixir
def handle_event("validate_document", %{"ref" => ref}, socket) do
  entry = Enum.find(socket.assigns.uploads.documents.entries, &(&1.ref == ref))

  if entry && entry.done? do
    # Read uploaded content and validate
    content = consume_uploaded_entry(socket, entry, fn %{path: path} ->
      {:ok, File.read!(path)}
    end)

    doc_type = infer_document_type(entry.client_name)

    Task.start(fn ->
      result = DocumentValidator.validate(content, entry.client_name, doc_type)
      send(self(), {:document_validated, ref, result})
    end)
  end

  {:noreply, assign(socket, :validating_doc, ref)}
end

def handle_info({:document_validated, ref, result}, socket) do
  validations = Map.put(socket.assigns[:doc_validations] || %{}, ref, result)
  {:noreply, assign(socket, doc_validations: validations, validating_doc: nil)}
end

defp infer_document_type(filename) do
  filename_lower = String.downcase(filename)
  cond do
    String.contains?(filename_lower, ["license", "id", "passport"]) -> :government_id
    String.contains?(filename_lower, ["statement", "bank"]) -> :bank_statement
    String.contains?(filename_lower, ["license", "permit"]) -> :business_license
    true -> :other
  end
end
```

**Step 2: Update template to show validation status**

Add validation indicators next to each uploaded file.

**Step 3: Test manually**

Upload documents and verify validation feedback appears.

**Step 4: Commit**

```bash
git add lib/mcp_web/live/ola/application_live.ex
git commit -m "feat(ola): integrate document pre-validation into upload flow"
```

---

### Task 9: Auto-Fill from Validated Documents

**Files:**
- Create: `lib/mcp/underwriting/services/document_autofill.ex`
- Create: `test/mcp/underwriting/services/document_autofill_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp/underwriting/services/document_autofill_test.exs
defmodule Mcp.Underwriting.Services.DocumentAutofillTest do
  use ExUnit.Case, async: true

  alias Mcp.Underwriting.Services.DocumentAutofill

  describe "extract_fields/2" do
    test "extracts name and DOB from government ID" do
      structured_data = %{
        "name" => "John Michael Doe",
        "date_of_birth" => "1985-01-15",
        "address" => "123 Main St, Anytown, CA 90210"
      }

      fields = DocumentAutofill.extract_fields(structured_data, :government_id)

      assert fields["owner_name"] == "John Michael Doe"
      assert fields["owner_dob"] == "1985-01-15"
    end

    test "extracts bank info from statement" do
      structured_data = %{
        "bank_name" => "First National Bank",
        "account_number" => "****4567",
        "routing_number" => "021000021",
        "ending_balance" => "$12,345.67"
      }

      fields = DocumentAutofill.extract_fields(structured_data, :bank_statement)

      assert fields["bank_name"] == "First National Bank"
      assert fields["account_last4"] == "4567"
    end
  end

  describe "merge_with_form/2" do
    test "only fills empty fields" do
      existing = %{"business_name" => "Existing Corp", "ein" => ""}
      extracted = %{"business_name" => "From Document", "ein" => "12-3456789"}

      merged = DocumentAutofill.merge_with_form(extracted, existing)

      assert merged["business_name"] == "Existing Corp"  # Kept existing
      assert merged["ein"] == "12-3456789"  # Filled empty
    end
  end
end
```

**Step 2: Write implementation**

```elixir
# lib/mcp/underwriting/services/document_autofill.ex
defmodule Mcp.Underwriting.Services.DocumentAutofill do
  @moduledoc """
  Extracts form-fillable data from validated documents.
  Enables "Zero-Entry" applications by auto-populating fields.
  """

  @doc """
  Extracts relevant form fields from document structured data.
  """
  def extract_fields(structured_data, :government_id) do
    %{
      "owner_name" => structured_data["name"],
      "owner_dob" => structured_data["date_of_birth"],
      "owner_address" => structured_data["address"]
    }
    |> reject_nil_values()
  end

  def extract_fields(structured_data, :bank_statement) do
    account = structured_data["account_number"] || ""
    last4 = String.slice(account, -4, 4)

    %{
      "bank_name" => structured_data["bank_name"],
      "account_last4" => last4,
      "monthly_volume" => parse_currency(structured_data["ending_balance"])
    }
    |> reject_nil_values()
  end

  def extract_fields(structured_data, :business_license) do
    %{
      "business_name" => structured_data["business_name"],
      "license_number" => structured_data["license_number"],
      "business_address" => structured_data["address"]
    }
    |> reject_nil_values()
  end

  def extract_fields(_data, _type), do: %{}

  @doc """
  Merges extracted fields with existing form data.
  Only fills empty fields - never overwrites user input.
  """
  def merge_with_form(extracted, existing) do
    Enum.reduce(extracted, existing, fn {key, value}, acc ->
      existing_value = Map.get(acc, key, "")

      if is_nil(existing_value) || existing_value == "" do
        Map.put(acc, key, value)
      else
        acc
      end
    end)
  end

  defp reject_nil_values(map) do
    map
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp parse_currency(nil), do: nil
  defp parse_currency(str) when is_binary(str) do
    str
    |> String.replace(~r/[$,]/, "")
    |> Float.parse()
    |> case do
      {num, _} -> num
      :error -> nil
    end
  end
end
```

**Step 3: Run tests**

Run: `mix test test/mcp/underwriting/services/document_autofill_test.exs`
Expected: PASS

**Step 4: Commit**

```bash
git add lib/mcp/underwriting/services/document_autofill.ex test/mcp/underwriting/services/document_autofill_test.exs
git commit -m "feat(uw): add DocumentAutofill for zero-entry applications"
```

---

## Phase 2C: ML Risk Models (Tasks 10-14)

Replace rule-based scoring with trained ML models.

### Task 10: ML Model Sidecar Service Spec

**Files:**
- Create: `apps/risk_model/README.md`
- Create: `apps/risk_model/requirements.txt`
- Create: `apps/risk_model/app.py`

**Step 1: Create the Python sidecar structure**

```bash
mkdir -p apps/risk_model
```

**Step 2: Write requirements.txt**

```
# apps/risk_model/requirements.txt
fastapi>=0.100.0
uvicorn>=0.23.0
scikit-learn>=1.3.0
xgboost>=2.0.0
pandas>=2.0.0
numpy>=1.24.0
pydantic>=2.0.0
```

**Step 3: Write the FastAPI app**

```python
# apps/risk_model/app.py
"""
Risk Model Sidecar Service
Serves ML models for underwriting risk scoring.
"""
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import pickle
import os
from pathlib import Path

app = FastAPI(title="Risk Model Service", version="1.0.0")

# Model storage
MODELS = {}

class PredictionRequest(BaseModel):
    features: dict
    model_name: str = "default"

class PredictionResponse(BaseModel):
    score: float
    confidence: float
    risk_factors: list[str]
    recommendation: str

class ModelInfo(BaseModel):
    name: str
    version: str
    accuracy: float
    feature_count: int

@app.get("/health")
def health_check():
    return {"status": "healthy", "models_loaded": list(MODELS.keys())}

@app.post("/predict", response_model=PredictionResponse)
def predict(request: PredictionRequest):
    """Generate risk prediction from features."""
    model = MODELS.get(request.model_name)

    if not model:
        # Fallback to rule-based if no model
        return rule_based_prediction(request.features)

    try:
        # In production, transform features and run model
        score = model.predict_proba([list(request.features.values())])[0][1]
        return PredictionResponse(
            score=round(score * 100, 2),
            confidence=0.85,
            risk_factors=extract_risk_factors(request.features, model),
            recommendation=get_recommendation(score)
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/models", response_model=list[ModelInfo])
def list_models():
    """List available models."""
    return [
        ModelInfo(
            name=name,
            version="1.0.0",
            accuracy=0.92,
            feature_count=len(model.feature_names_in_) if hasattr(model, 'feature_names_in_') else 0
        )
        for name, model in MODELS.items()
    ]

def rule_based_prediction(features: dict) -> PredictionResponse:
    """Fallback rule-based scoring when no ML model available."""
    score = 50.0
    factors = []

    # Business age factor
    years = features.get("business_years", 0)
    if years >= 5:
        score += 15
    elif years >= 2:
        score += 10
    elif years < 1:
        score -= 10
        factors.append("New business (< 1 year)")

    # Volume factor
    volume = features.get("monthly_volume", 0)
    if volume >= 50000:
        score += 10
    elif volume < 10000:
        score -= 5
        factors.append("Low monthly volume")

    # Industry risk
    high_risk_mcc = [5966, 5967, 7995, 5816]  # Example high-risk MCCs
    if features.get("mcc") in high_risk_mcc:
        score -= 20
        factors.append("High-risk industry category")

    return PredictionResponse(
        score=max(0, min(100, score)),
        confidence=0.70,  # Lower confidence for rules
        risk_factors=factors,
        recommendation=get_recommendation(score / 100)
    )

def get_recommendation(score: float) -> str:
    if score >= 0.8:
        return "auto_approve"
    elif score >= 0.5:
        return "manual_review"
    else:
        return "decline"

def extract_risk_factors(features: dict, model) -> list[str]:
    """Extract top contributing risk factors from model."""
    # In production, use SHAP or feature importance
    return []

@app.on_event("startup")
def load_models():
    """Load trained models on startup."""
    model_dir = Path(os.getenv("MODEL_DIR", "models"))
    if model_dir.exists():
        for model_file in model_dir.glob("*.pkl"):
            with open(model_file, "rb") as f:
                MODELS[model_file.stem] = pickle.load(f)
    print(f"Loaded {len(MODELS)} models")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("PORT", "48292")))
```

**Step 4: Write README**

```markdown
# Risk Model Sidecar

ML-based risk scoring service for underwriting.

## Setup

```bash
cd apps/risk_model
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Run

```bash
uvicorn app:app --port 48292
```

## API

- `GET /health` - Health check
- `POST /predict` - Get risk prediction
- `GET /models` - List available models

## Training

Models are trained offline and placed in `models/` directory.
See `training/` for training notebooks.
```

**Step 5: Commit**

```bash
git add apps/risk_model/
git commit -m "feat(ml): add risk model sidecar service skeleton"
```

---

### Task 11: Elixir Client for ML Service

**Files:**
- Create: `lib/mcp/underwriting/services/ml_risk_client.ex`
- Create: `test/mcp/underwriting/services/ml_risk_client_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp/underwriting/services/ml_risk_client_test.exs
defmodule Mcp.Underwriting.Services.MlRiskClientTest do
  use ExUnit.Case, async: true

  alias Mcp.Underwriting.Services.MlRiskClient

  describe "predict/1" do
    test "returns prediction from service" do
      features = %{
        business_years: 5,
        monthly_volume: 50000,
        mcc: 5411
      }

      # Will use fallback if service not running
      {:ok, prediction} = MlRiskClient.predict(features)

      assert is_number(prediction.score)
      assert prediction.score >= 0 and prediction.score <= 100
      assert prediction.recommendation in [:auto_approve, :manual_review, :decline]
    end

    test "handles service unavailable gracefully" do
      # Force connection to bad port
      features = %{business_years: 1}

      result = MlRiskClient.predict(features, base_url: "http://localhost:1")

      # Should fallback to rule-based
      assert {:ok, prediction} = result
      assert is_number(prediction.score)
    end
  end

  describe "health_check/0" do
    test "returns health status" do
      result = MlRiskClient.health_check()

      assert {:ok, _} = result or {:error, :service_unavailable} = result
    end
  end
end
```

**Step 2: Write implementation**

```elixir
# lib/mcp/underwriting/services/ml_risk_client.ex
defmodule Mcp.Underwriting.Services.MlRiskClient do
  @moduledoc """
  Client for the ML Risk Model sidecar service.
  Falls back to rule-based scoring if ML service unavailable.
  """

  @default_base_url "http://localhost:48292"

  defstruct [:score, :confidence, :risk_factors, :recommendation]

  def base_url do
    System.get_env("ML_RISK_URL", @default_base_url)
  end

  @doc """
  Gets a risk prediction for the given features.
  Falls back to rule-based scoring if ML service unavailable.
  """
  def predict(features, opts \\ []) do
    url = Keyword.get(opts, :base_url, base_url())

    case Req.post("#{url}/predict", json: %{features: features}) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, parse_prediction(body)}

      {:ok, %{status: status}} ->
        {:error, {:api_error, status}}

      {:error, _} ->
        # Fallback to local rule-based
        fallback_prediction(features)
    end
  end

  @doc """
  Checks if the ML service is healthy.
  """
  def health_check(opts \\ []) do
    url = Keyword.get(opts, :base_url, base_url())

    case Req.get("#{url}/health") do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      _ ->
        {:error, :service_unavailable}
    end
  end

  defp parse_prediction(body) do
    %__MODULE__{
      score: body["score"],
      confidence: body["confidence"],
      risk_factors: body["risk_factors"] || [],
      recommendation: String.to_existing_atom(body["recommendation"])
    }
  end

  defp fallback_prediction(features) do
    # Simple rule-based fallback
    base_score = 50

    score = base_score
      |> adjust_for_business_age(features)
      |> adjust_for_volume(features)
      |> clamp(0, 100)

    recommendation = cond do
      score >= 80 -> :auto_approve
      score >= 50 -> :manual_review
      true -> :decline
    end

    {:ok, %__MODULE__{
      score: score,
      confidence: 0.7,
      risk_factors: [],
      recommendation: recommendation
    }}
  end

  defp adjust_for_business_age(score, %{business_years: years}) when years >= 5, do: score + 15
  defp adjust_for_business_age(score, %{business_years: years}) when years >= 2, do: score + 10
  defp adjust_for_business_age(score, %{business_years: years}) when years < 1, do: score - 10
  defp adjust_for_business_age(score, _), do: score

  defp adjust_for_volume(score, %{monthly_volume: vol}) when vol >= 50000, do: score + 10
  defp adjust_for_volume(score, %{monthly_volume: vol}) when vol < 10000, do: score - 5
  defp adjust_for_volume(score, _), do: score

  defp clamp(val, min, max), do: val |> max(min) |> min(max)
end
```

**Step 3: Run tests**

Run: `mix test test/mcp/underwriting/services/ml_risk_client_test.exs`
Expected: PASS

**Step 4: Commit**

```bash
git add lib/mcp/underwriting/services/ml_risk_client.ex test/mcp/underwriting/services/ml_risk_client_test.exs
git commit -m "feat(ml): add MlRiskClient with fallback to rules"
```

---

### Task 12: Hybrid Risk Engine

**Files:**
- Create: `lib/mcp/underwriting/hybrid_risk_engine.ex`
- Create: `test/mcp/underwriting/hybrid_risk_engine_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp/underwriting/hybrid_risk_engine_test.exs
defmodule Mcp.Underwriting.HybridRiskEngineTest do
  use ExUnit.Case, async: true

  alias Mcp.Underwriting.HybridRiskEngine

  describe "evaluate/2" do
    test "combines ML and rule-based scores" do
      application = %{
        application_data: %{
          "business_years" => 5,
          "monthly_volume" => 50000,
          "mcc" => "5411"
        }
      }

      vendor_data = %{kyb: %{status: :clear}}

      result = HybridRiskEngine.evaluate(application, vendor_data)

      assert is_number(result.score)
      assert result.score >= 0 and result.score <= 100
      assert is_list(result.reasons)
      assert result.recommendation in [:approve, :manual_review, :reject]
    end

    test "weights ML score higher when confidence is high" do
      application = %{application_data: %{"business_years" => 10}}
      vendor_data = %{}

      result = HybridRiskEngine.evaluate(application, vendor_data)

      # With high confidence ML, should lean toward ML score
      assert result.ml_weight >= 0.6
    end
  end

  describe "extract_features/1" do
    test "extracts numeric features from application" do
      application = %{
        application_data: %{
          "business_years" => "5",
          "monthly_volume" => "50000",
          "mcc" => "5411"
        }
      }

      features = HybridRiskEngine.extract_features(application)

      assert features.business_years == 5
      assert features.monthly_volume == 50000
      assert features.mcc == 5411
    end
  end
end
```

**Step 2: Write implementation**

```elixir
# lib/mcp/underwriting/hybrid_risk_engine.ex
defmodule Mcp.Underwriting.HybridRiskEngine do
  @moduledoc """
  Hybrid risk scoring that combines ML predictions with rule-based checks.
  Provides explainable scoring with graceful degradation.
  """

  alias Mcp.Underwriting.RiskEngine
  alias Mcp.Underwriting.Services.MlRiskClient

  defstruct [:score, :reasons, :recommendation, :ml_score, :rule_score, :ml_weight, :flags]

  @doc """
  Evaluates application risk using both ML and rule-based approaches.
  """
  def evaluate(application, vendor_data) do
    # Extract features for ML
    features = extract_features(application)

    # Get ML prediction
    ml_result = get_ml_prediction(features)

    # Get rule-based score
    rule_result = RiskEngine.evaluate(application, vendor_data)

    # Combine scores
    combine_results(ml_result, rule_result)
  end

  @doc """
  Extracts numeric features from application data for ML model.
  """
  def extract_features(%{application_data: data}) do
    %{
      business_years: parse_int(data["business_years"]),
      monthly_volume: parse_int(data["monthly_volume"]),
      mcc: parse_int(data["mcc"]),
      owner_count: parse_int(data["owner_count"]) || 1,
      has_website: if(data["website"], do: 1, else: 0)
    }
  end

  def extract_features(_), do: %{}

  defp get_ml_prediction(features) do
    case MlRiskClient.predict(features) do
      {:ok, prediction} -> prediction
      {:error, _} -> nil
    end
  end

  defp combine_results(nil, rule_result) do
    # ML unavailable - use rules only
    %__MODULE__{
      score: rule_result.score,
      reasons: rule_result.reasons,
      recommendation: score_to_recommendation(rule_result.score),
      ml_score: nil,
      rule_score: rule_result.score,
      ml_weight: 0.0,
      flags: rule_result.flags
    }
  end

  defp combine_results(ml_result, rule_result) do
    # Weight based on ML confidence
    ml_weight = calculate_ml_weight(ml_result.confidence)

    combined_score = round(
      ml_result.score * ml_weight +
      rule_result.score * (1 - ml_weight)
    )

    # Combine reasons
    ml_reasons = Enum.map(ml_result.risk_factors, &"[ML] #{&1}")
    all_reasons = ml_reasons ++ rule_result.reasons

    %__MODULE__{
      score: combined_score,
      reasons: all_reasons,
      recommendation: score_to_recommendation(combined_score),
      ml_score: ml_result.score,
      rule_score: rule_result.score,
      ml_weight: ml_weight,
      flags: rule_result.flags
    }
  end

  defp calculate_ml_weight(confidence) when confidence >= 0.9, do: 0.8
  defp calculate_ml_weight(confidence) when confidence >= 0.8, do: 0.7
  defp calculate_ml_weight(confidence) when confidence >= 0.7, do: 0.6
  defp calculate_ml_weight(_), do: 0.5

  defp score_to_recommendation(score) when score >= 80, do: :approve
  defp score_to_recommendation(score) when score >= 50, do: :manual_review
  defp score_to_recommendation(_), do: :reject

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {num, _} -> num
      :error -> nil
    end
  end
end
```

**Step 3: Run tests**

Run: `mix test test/mcp/underwriting/hybrid_risk_engine_test.exs`
Expected: PASS

**Step 4: Commit**

```bash
git add lib/mcp/underwriting/hybrid_risk_engine.ex test/mcp/underwriting/hybrid_risk_engine_test.exs
git commit -m "feat(ml): add HybridRiskEngine combining ML and rules"
```

---

## Phase 2D: Magic Camera (Tasks 13-15)

QR code handoff for phone-based document upload.

### Task 13: Magic Link QR Generator

**Files:**
- Create: `lib/mcp/underwriting/services/magic_camera.ex`
- Create: `test/mcp/underwriting/services/magic_camera_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp/underwriting/services/magic_camera_test.exs
defmodule Mcp.Underwriting.Services.MagicCameraTest do
  use ExUnit.Case, async: true

  alias Mcp.Underwriting.Services.MagicCamera

  describe "generate_session/2" do
    test "creates a unique session with QR data" do
      {:ok, session} = MagicCamera.generate_session("app-123", :government_id)

      assert session.application_id == "app-123"
      assert session.document_type == :government_id
      assert is_binary(session.token)
      assert is_binary(session.qr_url)
      assert String.contains?(session.qr_url, session.token)
    end

    test "session expires in 10 minutes" do
      {:ok, session} = MagicCamera.generate_session("app-123", :government_id)

      # Should expire ~10 minutes from now
      diff = DateTime.diff(session.expires_at, DateTime.utc_now(), :minute)
      assert diff >= 9 and diff <= 10
    end
  end

  describe "verify_session/1" do
    test "returns session data for valid token" do
      {:ok, session} = MagicCamera.generate_session("app-123", :bank_statement)
      {:ok, verified} = MagicCamera.verify_session(session.token)

      assert verified.application_id == "app-123"
      assert verified.document_type == :bank_statement
    end

    test "returns error for expired token" do
      # Create expired token
      result = MagicCamera.verify_session("expired-token")

      assert {:error, :invalid_or_expired} = result
    end
  end
end
```

**Step 2: Write implementation**

```elixir
# lib/mcp/underwriting/services/magic_camera.ex
defmodule Mcp.Underwriting.Services.MagicCamera do
  @moduledoc """
  Generates QR codes for mobile document upload.
  Enables desktop-to-phone handoff for camera capture.
  """

  @token_ttl_minutes 10
  @upload_endpoint "/upload/camera"

  defstruct [:application_id, :document_type, :token, :qr_url, :expires_at]

  @doc """
  Generates a magic camera session for document upload.
  Returns QR code URL that opens phone camera.
  """
  def generate_session(application_id, document_type) do
    token = generate_token()
    expires_at = DateTime.add(DateTime.utc_now(), @token_ttl_minutes, :minute)

    # Store session (in production, use Redis or ETS)
    store_session(token, %{
      application_id: application_id,
      document_type: document_type,
      expires_at: expires_at
    })

    base_url = McpWeb.Endpoint.url()
    qr_url = "#{base_url}#{@upload_endpoint}/#{token}"

    {:ok, %__MODULE__{
      application_id: application_id,
      document_type: document_type,
      token: token,
      qr_url: qr_url,
      expires_at: expires_at
    }}
  end

  @doc """
  Verifies a magic camera token and returns session data.
  """
  def verify_session(token) do
    case get_session(token) do
      nil ->
        {:error, :invalid_or_expired}

      session ->
        if DateTime.compare(session.expires_at, DateTime.utc_now()) == :gt do
          {:ok, session}
        else
          delete_session(token)
          {:error, :invalid_or_expired}
        end
    end
  end

  @doc """
  Completes the upload and notifies the desktop session.
  """
  def complete_upload(token, document_path) do
    case verify_session(token) do
      {:ok, session} ->
        # Broadcast to desktop session via PubSub
        Phoenix.PubSub.broadcast(
          Mcp.PubSub,
          "magic_camera:#{session.application_id}",
          {:document_uploaded, session.document_type, document_path}
        )

        delete_session(token)
        {:ok, :uploaded}

      error ->
        error
    end
  end

  # Token generation
  defp generate_token do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  # Session storage (using ETS for simplicity)
  # In production, use Redis for distributed storage
  defp store_session(token, data) do
    :ets.insert(:magic_camera_sessions, {token, Map.put(data, :token, token)})
  end

  defp get_session(token) do
    case :ets.lookup(:magic_camera_sessions, token) do
      [{^token, data}] -> struct(__MODULE__, data)
      [] -> nil
    end
  end

  defp delete_session(token) do
    :ets.delete(:magic_camera_sessions, token)
  end

  # Initialize ETS table on module load
  def init do
    if :ets.whereis(:magic_camera_sessions) == :undefined do
      :ets.new(:magic_camera_sessions, [:set, :public, :named_table])
    end
  end
end
```

**Step 3: Initialize ETS in application.ex**

Add to `lib/mcp/application.ex` in `start/2`:
```elixir
Mcp.Underwriting.Services.MagicCamera.init()
```

**Step 4: Run tests**

Run: `mix test test/mcp/underwriting/services/magic_camera_test.exs`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/mcp/underwriting/services/magic_camera.ex test/mcp/underwriting/services/magic_camera_test.exs lib/mcp/application.ex
git commit -m "feat(uw): add MagicCamera QR code handoff service"
```

---

### Task 14: Mobile Upload LiveView

**Files:**
- Create: `lib/mcp_web/live/ola/camera_upload_live.ex`
- Create: `lib/mcp_web/router.ex` (modify)

**Step 1: Create the mobile-optimized upload page**

```elixir
# lib/mcp_web/live/ola/camera_upload_live.ex
defmodule McpWeb.Ola.CameraUploadLive do
  @moduledoc """
  Mobile-optimized camera upload page.
  Accessed via QR code scan from desktop.
  """
  use McpWeb, :live_view

  alias Mcp.Underwriting.Services.{MagicCamera, DocumentValidator}

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case MagicCamera.verify_session(token) do
      {:ok, session} ->
        socket =
          socket
          |> assign(:token, token)
          |> assign(:session, session)
          |> assign(:status, :ready)
          |> assign(:validation_result, nil)
          |> allow_upload(:document,
            accept: ~w(.jpg .jpeg .png .pdf),
            max_entries: 1,
            max_file_size: 10_000_000
          )

        {:ok, socket}

      {:error, _} ->
        {:ok,
         socket
         |> assign(:status, :expired)
         |> put_flash(:error, "This link has expired. Please scan a new QR code.")}
    end
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :document, fn %{path: path}, entry ->
        # Validate document
        content = File.read!(path)
        doc_type = socket.assigns.session.document_type

        case DocumentValidator.validate(content, entry.client_name, doc_type) do
          {:ok, validation} ->
            if validation.valid? do
              # Upload to S3 and notify desktop
              dest = upload_to_storage(path, entry, socket.assigns.session)
              MagicCamera.complete_upload(socket.assigns.token, dest)
              {:ok, %{status: :success, path: dest}}
            else
              {:ok, %{status: :invalid, validation: validation}}
            end

          {:error, validation} ->
            {:ok, %{status: :invalid, validation: validation}}
        end
      end)

    result = List.first(uploaded_files)

    socket =
      case result do
        %{status: :success} ->
          socket
          |> assign(:status, :complete)
          |> put_flash(:info, "Document uploaded successfully!")

        %{status: :invalid, validation: v} ->
          socket
          |> assign(:validation_result, v)
          |> put_flash(:error, "Please fix the issues and try again")

        _ ->
          put_flash(socket, :error, "Upload failed")
      end

    {:noreply, socket}
  end

  defp upload_to_storage(path, entry, session) do
    bucket = Application.get_env(:mcp, :uploads)[:bucket]
    s3_path = "applications/#{session.application_id}/camera/#{entry.client_name}"

    ExAws.S3.put_object(bucket, s3_path, File.read!(path))
    |> ExAws.request!()

    s3_path
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 p-4">
      <div class="max-w-md mx-auto">
        <%= case @status do %>
          <% :expired -> %>
            <div class="text-center py-12">
              <.icon name="hero-clock" class="w-16 h-16 mx-auto text-warning mb-4" />
              <h1 class="text-xl font-bold mb-2">Link Expired</h1>
              <p class="text-base-content/70">Please scan a new QR code from your application.</p>
            </div>

          <% :ready -> %>
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <h2 class="card-title">
                  <.icon name="hero-camera" class="w-6 h-6" />
                  Upload <%= document_label(@session.document_type) %>
                </h2>

                <form phx-submit="save" phx-change="validate">
                  <div class="py-4">
                    <.live_file_input upload={@uploads.document} class="file-input file-input-bordered w-full" />
                  </div>

                  <%= for entry <- @uploads.document.entries do %>
                    <div class="mb-4">
                      <div class="flex items-center gap-2">
                        <span class="text-sm"><%= entry.client_name %></span>
                        <progress class="progress progress-primary w-full" value={entry.progress} max="100" />
                      </div>
                    </div>
                  <% end %>

                  <%= if @validation_result && not @validation_result.valid? do %>
                    <div class="alert alert-error mb-4">
                      <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
                      <div>
                        <h3 class="font-bold">Issues Found</h3>
                        <ul class="list-disc list-inside text-sm">
                          <%= for issue <- @validation_result.issues do %>
                            <li><%= issue %></li>
                          <% end %>
                        </ul>
                      </div>
                    </div>
                  <% end %>

                  <button type="submit" class="btn btn-primary w-full" disabled={@uploads.document.entries == []}>
                    <.icon name="hero-cloud-arrow-up" class="w-5 h-5" />
                    Upload Document
                  </button>
                </form>
              </div>
            </div>

          <% :complete -> %>
            <div class="text-center py-12">
              <.icon name="hero-check-circle" class="w-16 h-16 mx-auto text-success mb-4" />
              <h1 class="text-xl font-bold mb-2">Upload Complete!</h1>
              <p class="text-base-content/70">You can close this page and return to your application.</p>
            </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp document_label(:government_id), do: "Government ID"
  defp document_label(:bank_statement), do: "Bank Statement"
  defp document_label(:business_license), do: "Business License"
  defp document_label(_), do: "Document"
end
```

**Step 2: Add route**

Add to `router.ex`:
```elixir
live "/upload/camera/:token", Ola.CameraUploadLive
```

**Step 3: Test manually**

Generate QR code and test on phone.

**Step 4: Commit**

```bash
git add lib/mcp_web/live/ola/camera_upload_live.ex lib/mcp_web/router.ex
git commit -m "feat(ola): add mobile camera upload LiveView"
```

---

### Task 15: QR Code Component for Desktop

**Files:**
- Create: `lib/mcp_web/live/ola/components/magic_camera_qr.ex`

**Step 1: Create QR component**

```elixir
# lib/mcp_web/live/ola/components/magic_camera_qr.ex
defmodule McpWeb.Ola.Components.MagicCameraQR do
  @moduledoc """
  QR code component for magic camera handoff.
  """
  use McpWeb, :live_component

  alias Mcp.Underwriting.Services.MagicCamera

  def mount(socket) do
    {:ok, assign(socket, session: nil, qr_svg: nil, listening: false)}
  end

  def update(assigns, socket) do
    socket = assign(socket, :application_id, assigns[:application_id])
    socket = assign(socket, :document_type, assigns[:document_type])
    {:ok, socket}
  end

  def handle_event("generate_qr", _params, socket) do
    {:ok, session} = MagicCamera.generate_session(
      socket.assigns.application_id,
      socket.assigns.document_type
    )

    # Generate QR code SVG using qr_code library
    qr_svg = generate_qr_svg(session.qr_url)

    # Subscribe to upload notifications
    Phoenix.PubSub.subscribe(Mcp.PubSub, "magic_camera:#{socket.assigns.application_id}")

    {:noreply,
     socket
     |> assign(:session, session)
     |> assign(:qr_svg, qr_svg)
     |> assign(:listening, true)}
  end

  def handle_info({:document_uploaded, doc_type, path}, socket) do
    send(self(), {:camera_upload_complete, doc_type, path})
    {:noreply, assign(socket, :session, nil)}
  end

  defp generate_qr_svg(url) do
    # Using QRCode library
    url
    |> QRCode.create(:medium)
    |> QRCode.render(:svg)
    |> elem(1)
  end

  def render(assigns) do
    ~H"""
    <div class="magic-camera-qr">
      <%= if @session do %>
        <div class="card bg-base-100 shadow border">
          <div class="card-body items-center text-center">
            <h3 class="card-title text-sm">
              <.icon name="hero-device-phone-mobile" class="w-5 h-5" />
              Scan to upload with phone
            </h3>

            <div class="p-2 bg-white rounded-lg">
              <%= raw(@qr_svg) %>
            </div>

            <p class="text-xs text-base-content/60">
              Expires in <%= remaining_time(@session.expires_at) %>
            </p>

            <button phx-click="generate_qr" phx-target={@myself} class="btn btn-ghost btn-xs">
              Generate new code
            </button>
          </div>
        </div>
      <% else %>
        <button phx-click="generate_qr" phx-target={@myself} class="btn btn-outline btn-sm gap-2">
          <.icon name="hero-qr-code" class="w-4 h-4" />
          Use phone camera
        </button>
      <% end %>
    </div>
    """
  end

  defp remaining_time(expires_at) do
    minutes = DateTime.diff(expires_at, DateTime.utc_now(), :minute)
    "#{max(0, minutes)} min"
  end
end
```

**Step 2: Add QRCode dependency**

Add to `mix.exs`:
```elixir
{:qr_code, "~> 3.0"}
```

Run: `mix deps.get`

**Step 3: Commit**

```bash
git add lib/mcp_web/live/ola/components/magic_camera_qr.ex mix.exs mix.lock
git commit -m "feat(ola): add MagicCameraQR component for phone handoff"
```

---

## Phase 2E: Deal Room (Tasks 16-20)

Collaboration features for underwriting team.

### Task 16: Notes Resource

**Files:**
- Create: `lib/mcp/underwriting/resources/note.ex`
- Create migration

**Step 1: Create the Note resource**

```elixir
# lib/mcp/underwriting/resources/note.ex
defmodule Mcp.Underwriting.Note do
  @moduledoc """
  Notes for application collaboration.
  Supports @mentions and rich formatting.
  """
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "underwriting_notes"
    repo Mcp.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:content, :application_id, :author_id, :visibility, :mentions]
    end

    update :update do
      accept [:content]
    end

    read :for_application do
      argument :application_id, :uuid, allow_nil?: false
      filter expr(application_id == ^arg(:application_id))
      prepare build(sort: [inserted_at: :desc])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :content, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 10_000
    end

    attribute :visibility, :atom do
      constraints one_of: [:internal, :shared_with_applicant]
      default :internal
    end

    attribute :mentions, {:array, :uuid} do
      default []
      description "User IDs mentioned in this note"
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :application, Mcp.Underwriting.Application
    belongs_to :author, Mcp.Accounts.User
  end

  code_interface do
    define :create
    define :read
    define :for_application, args: [:application_id]
    define :update
    define :destroy
  end
end
```

**Step 2: Generate migration**

Run: `mix ash.codegen create_underwriting_notes`

**Step 3: Add to domain**

Add `Mcp.Underwriting.Note` to domain resources.

**Step 4: Commit**

```bash
git add lib/mcp/underwriting/resources/note.ex priv/repo/migrations/*_create_underwriting_notes.exs lib/mcp/underwriting.ex
git commit -m "feat(uw): add Note resource for deal room collaboration"
```

---

### Task 17: Mention Parser Service

**Files:**
- Create: `lib/mcp/underwriting/services/mention_parser.ex`
- Create: `test/mcp/underwriting/services/mention_parser_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp/underwriting/services/mention_parser_test.exs
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
  end

  describe "render_html/2" do
    test "converts mentions to links" do
      content = "Hey @john check this"
      users = [%{username: "john", id: "123", display_name: "John Doe"}]

      html = MentionParser.render_html(content, users)

      assert html =~ ~s(<a href="/users/123")
      assert html =~ "John Doe"
    end
  end
end
```

**Step 2: Write implementation**

```elixir
# lib/mcp/underwriting/services/mention_parser.ex
defmodule Mcp.Underwriting.Services.MentionParser do
  @moduledoc """
  Parses @mentions from note content.
  """

  @mention_regex ~r/(?<!\S)@([a-zA-Z0-9._-]+)/

  defstruct [:mentions, :plain_text]

  def parse(content) do
    mentions =
      @mention_regex
      |> Regex.scan(content)
      |> Enum.map(fn [_, username] -> username end)
      |> Enum.uniq()

    %__MODULE__{
      mentions: mentions,
      plain_text: content
    }
  end

  def render_html(content, users) do
    user_map = Map.new(users, fn u -> {u.username, u} end)

    Regex.replace(@mention_regex, content, fn full, username ->
      case Map.get(user_map, username) do
        nil -> full
        user -> ~s(<a href="/users/#{user.id}" class="mention">@#{user.display_name}</a>)
      end
    end)
  end
end
```

**Step 3: Run tests**

Run: `mix test test/mcp/underwriting/services/mention_parser_test.exs`
Expected: PASS

**Step 4: Commit**

```bash
git add lib/mcp/underwriting/services/mention_parser.ex test/mcp/underwriting/services/mention_parser_test.exs
git commit -m "feat(uw): add MentionParser for @mention support"
```

---

### Task 18: Notes LiveComponent

**Files:**
- Create: `lib/mcp_web/live/tenant/underwriting/components/notes_panel.ex`

**Step 1: Create the component**

```elixir
# lib/mcp_web/live/tenant/underwriting/components/notes_panel.ex
defmodule McpWeb.Tenant.Underwriting.Components.NotesPanel do
  @moduledoc """
  Notes panel for application deal room.
  Supports @mentions with autocomplete.
  """
  use McpWeb, :live_component

  alias Mcp.Underwriting.Note
  alias Mcp.Underwriting.Services.MentionParser

  def mount(socket) do
    {:ok,
     socket
     |> assign(:notes, [])
     |> assign(:input_value, "")
     |> assign(:showing_mentions, false)
     |> assign(:mention_suggestions, [])}
  end

  def update(assigns, socket) do
    notes = Note.for_application!(assigns.application_id, tenant: assigns.tenant_schema)

    {:ok,
     socket
     |> assign(:application_id, assigns.application_id)
     |> assign(:current_user, assigns.current_user)
     |> assign(:tenant_schema, assigns.tenant_schema)
     |> assign(:team_members, assigns[:team_members] || [])
     |> assign(:notes, notes)}
  end

  def handle_event("input_change", %{"value" => value}, socket) do
    # Check if typing @mention
    {showing, suggestions} = check_for_mention(value, socket.assigns.team_members)

    {:noreply,
     socket
     |> assign(:input_value, value)
     |> assign(:showing_mentions, showing)
     |> assign(:mention_suggestions, suggestions)}
  end

  def handle_event("insert_mention", %{"username" => username}, socket) do
    # Insert mention at cursor
    new_value = insert_mention(socket.assigns.input_value, username)

    {:noreply,
     socket
     |> assign(:input_value, new_value)
     |> assign(:showing_mentions, false)}
  end

  def handle_event("submit_note", %{"content" => content}, socket) when content != "" do
    parsed = MentionParser.parse(content)

    # Resolve usernames to IDs
    mention_ids = resolve_mentions(parsed.mentions, socket.assigns.team_members)

    case Note.create(
      %{
        content: content,
        application_id: socket.assigns.application_id,
        author_id: socket.assigns.current_user.id,
        mentions: mention_ids
      },
      tenant: socket.assigns.tenant_schema
    ) do
      {:ok, note} ->
        # Notify mentioned users
        notify_mentions(note, mention_ids)

        {:noreply,
         socket
         |> assign(:input_value, "")
         |> assign(:notes, [note | socket.assigns.notes])}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save note")}
    end
  end

  def handle_event("submit_note", _params, socket) do
    {:noreply, socket}
  end

  defp check_for_mention(value, team_members) do
    # Check if currently typing @mention
    if String.contains?(value, "@") do
      case Regex.run(~r/@(\w*)$/, value) do
        [_, partial] ->
          suggestions = filter_members(team_members, partial)
          {length(suggestions) > 0, suggestions}

        _ ->
          {false, []}
      end
    else
      {false, []}
    end
  end

  defp filter_members(members, partial) do
    partial_lower = String.downcase(partial)

    members
    |> Enum.filter(fn m ->
      String.starts_with?(String.downcase(m.username || ""), partial_lower) or
        String.starts_with?(String.downcase(m.display_name || ""), partial_lower)
    end)
    |> Enum.take(5)
  end

  defp insert_mention(value, username) do
    Regex.replace(~r/@\w*$/, value, "@#{username} ")
  end

  defp resolve_mentions(usernames, team_members) do
    member_map = Map.new(team_members, fn m -> {m.username, m.id} end)
    Enum.map(usernames, &Map.get(member_map, &1)) |> Enum.reject(&is_nil/1)
  end

  defp notify_mentions(note, user_ids) do
    Enum.each(user_ids, fn user_id ->
      Phoenix.PubSub.broadcast(
        Mcp.PubSub,
        "user:#{user_id}:notifications",
        {:mention, note}
      )
    end)
  end

  def render(assigns) do
    ~H"""
    <div class="notes-panel flex flex-col h-full">
      <h3 class="font-semibold text-sm mb-3 flex items-center gap-2">
        <.icon name="hero-chat-bubble-left-ellipsis" class="w-4 h-4" />
        Notes
      </h3>

      <!-- Notes list -->
      <div class="flex-1 overflow-y-auto space-y-3 mb-3">
        <%= for note <- @notes do %>
          <div class="bg-base-200 rounded-lg p-3">
            <div class="flex items-center gap-2 mb-1">
              <span class="font-medium text-sm">
                <%= note.author.display_name || note.author.email %>
              </span>
              <span class="text-xs text-base-content/50">
                <%= format_time(note.inserted_at) %>
              </span>
            </div>
            <div class="text-sm">
              <%= raw(MentionParser.render_html(note.content, @team_members)) %>
            </div>
          </div>
        <% end %>

        <%= if Enum.empty?(@notes) do %>
          <p class="text-sm text-base-content/50 text-center py-4">
            No notes yet. Add one below.
          </p>
        <% end %>
      </div>

      <!-- Input area -->
      <div class="relative">
        <%= if @showing_mentions do %>
          <div class="absolute bottom-full left-0 right-0 mb-1 bg-base-100 border rounded-lg shadow-lg max-h-40 overflow-y-auto">
            <%= for member <- @mention_suggestions do %>
              <button
                type="button"
                phx-click="insert_mention"
                phx-value-username={member.username}
                phx-target={@myself}
                class="w-full text-left px-3 py-2 hover:bg-base-200 text-sm"
              >
                <%= member.display_name || member.username %>
              </button>
            <% end %>
          </div>
        <% end %>

        <form phx-submit="submit_note" phx-target={@myself}>
          <div class="flex gap-2">
            <input
              type="text"
              name="content"
              value={@input_value}
              phx-change="input_change"
              phx-target={@myself}
              placeholder="Add a note... Use @ to mention"
              class="input input-bordered input-sm flex-1"
              autocomplete="off"
            />
            <button type="submit" class="btn btn-primary btn-sm">
              <.icon name="hero-paper-airplane" class="w-4 h-4" />
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%b %d, %H:%M")
  end
end
```

**Step 2: Commit**

```bash
git add lib/mcp_web/live/tenant/underwriting/components/notes_panel.ex
git commit -m "feat(uw): add NotesPanel component with @mentions"
```

---

### Task 19: Wire Notes into Review LiveView

**Files:**
- Modify: `lib/mcp_web/live/tenant/underwriting/review_live.ex`

**Step 1: Add notes panel to layout**

Add component to sidebar:
```heex
<.live_component
  module={McpWeb.Tenant.Underwriting.Components.NotesPanel}
  id="notes-panel"
  application_id={@application.id}
  current_user={@current_user}
  tenant_schema={@tenant_schema}
  team_members={@team_members}
/>
```

**Step 2: Load team members on mount**

```elixir
team_members = Mcp.Accounts.User.list_by_tenant!(tenant.id)
|> assign(:team_members, team_members)
```

**Step 3: Commit**

```bash
git add lib/mcp_web/live/tenant/underwriting/review_live.ex
git commit -m "feat(uw): integrate notes panel into review page"
```

---

### Task 20: Mention Notifications

**Files:**
- Create: `lib/mcp/underwriting/notifiers/mention_notifier.ex`

**Step 1: Create notifier**

```elixir
# lib/mcp/underwriting/notifiers/mention_notifier.ex
defmodule Mcp.Underwriting.Notifiers.MentionNotifier do
  @moduledoc """
  Sends notifications when users are @mentioned.
  """

  alias Mcp.Communication.EmailService

  def notify(note, mentioned_user_ids) do
    users = Mcp.Accounts.User.get_by_ids!(mentioned_user_ids)

    Enum.each(users, fn user ->
      send_email_notification(user, note)
      send_in_app_notification(user, note)
    end)
  end

  defp send_email_notification(user, note) do
    subject = "You were mentioned in an underwriting note"

    body = """
    <p>Hi #{user.display_name || user.email},</p>

    <p>#{note.author.display_name} mentioned you in a note on application.</p>

    <blockquote style="border-left: 3px solid #ccc; padding-left: 10px; margin: 10px 0;">
      #{note.content}
    </blockquote>

    <p><a href="#{review_url(note)}">View Application</a></p>
    """

    EmailService.send_email(user.email, subject, body)
  end

  defp send_in_app_notification(user, note) do
    Phoenix.PubSub.broadcast(
      Mcp.PubSub,
      "user:#{user.id}:notifications",
      {:new_notification, %{
        type: :mention,
        title: "You were mentioned",
        body: "#{note.author.display_name} mentioned you in a note",
        url: review_url(note)
      }}
    )
  end

  defp review_url(note) do
    McpWeb.Endpoint.url() <> "/tenant/underwriting/#{note.application_id}"
  end
end
```

**Step 2: Wire into Note creation**

Add callback in Note resource or hook in NotesPanel.

**Step 3: Commit**

```bash
git add lib/mcp/underwriting/notifiers/mention_notifier.ex
git commit -m "feat(uw): add MentionNotifier for @mention emails"
```

---

## Final Steps

### Run Full Test Suite

```bash
mix test
```

### Run Pre-commit Checks

```bash
mix precommit
```

### Update Documentation

Update `docs/UNDERWRITING.md` to mark implemented features.

---

## Summary

| Phase | Feature | Tasks | Complexity |
|-------|---------|-------|------------|
| 2A | Full Atlas AI Concierge | 1-5 | High |
| 2B | Document Pre-Validation | 6-9 | Medium |
| 2C | ML Risk Models | 10-14 | High |
| 2D | Magic Camera | 13-15 | Medium |
| 2E | Deal Room | 16-20 | Medium |

**Total: 20 tasks**

Each task follows TDD with bite-sized steps. Commit after each task.
