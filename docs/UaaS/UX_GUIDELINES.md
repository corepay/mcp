# Agentic UaaS UX Guidelines

## 1. The "Training" Interface (Tenant Admin)

Tenants need a UI to "train" their digital employees. This is **NOT** a settings
page with checkboxes. It should feel like writing a job description or a policy
memo.

### The "Instruction Editor"

- **Visual Metaphor**: A Notion-like document editor.
- **Interaction**: The Tenant writes natural language instructions.
- **AI Feedback**: As they type, the system highlights ambiguous instructions.
  - _Tenant types_: "Reject risky loans."
  - _AI Highlight_: "⚠️ 'Risky' is vague. Do you mean Credit Score < 600 or DTI
    > 50%?"

### The "Playground" (Simulator)

Before deploying an Instruction Set, the Tenant must test it.

- **UI**: Split screen. Left side = Instructions. Right side = "Test Case".
- **Action**: Tenant uploads a sample PDF.
- **Result**: The Agent runs in real-time. "Based on your instructions, I would
  **Reject** this because DTI is 45%."

## 2. The "Applicant" Interface (Ola)

The applicant experience remains conversational ("Atlas"), but now Atlas is
powered by the specific **Instruction Set**.

- **Scenario**: Tenant configured "Ask for explanation if gap in employment > 3
  months."
- **Atlas Behavior**: Atlas detects a gap in the uploaded resume.
- **Atlas Chat**: "I noticed a gap in 2023. Can you tell me a bit about that?
  (My instructions require me to ask)."

## 3. The "Deal Room" (Human Review)

When an Agent flags a file for review, the Human Underwriter needs to see _why_.

- **The "Brain Trace"**: Don't just show the result. Show the thinking.
  - "I calculated income as $5,000/mo."
  - "Reasoning: I saw $6,000 in deposits, but excluded $1,000 from 'Venmo' per
    Instruction #4."
- **Override**: The Human can click "Correct" on the logic. "Actually, count
  Venmo for this applicant." -> The Agent learns (or just updates this case).
