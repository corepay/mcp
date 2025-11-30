# RAG User Guide

## Managing Knowledge Bases

A **Knowledge Base** is like a virtual library for your AI agents. You can
create different Knowledge Bases for different topics (e.g., "HR Policies",
"Technical Support", "Sales Playbook").

### Creating a Knowledge Base

1. Navigate to the **AI Settings** in your dashboard.
2. Click **New Knowledge Base**.
3. Enter a name and description.
4. Assign it to a specific scope (e.g., a specific Merchant) if necessary.

### Adding Documents

You can add documents to a Knowledge Base by:

- **Uploading Files**: PDF, DOCX, or TXT files.
- **Manual Entry**: Pasting text directly into the editor.

The system will automatically process these documents, break them into chunks,
and make them searchable for the AI.

## Connecting to Agents

To make an agent "smart" about a specific topic:

1. Go to the **Agents** configuration page.
2. Select the agent you want to update.
3. In the **Knowledge Sources** section, select the Knowledge Bases you want
   this agent to access.
4. Save your changes.

Now, when you ask the agent a question, it will first look through the connected
Knowledge Bases to find the answer.
