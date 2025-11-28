defmodule Mcp.Communication.EmailService do
  @moduledoc """
  EmailService delegating to Mcp.Mailer (Swoosh).
  """

  use GenServer
  require Logger
  import Swoosh.Email

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting Communication EmailService")
    {:ok, %{templates: %{}}}
  end

  def send_email(to, subject, body, opts \\ []) do
    GenServer.call(__MODULE__, {:send_email, to, subject, body, opts})
  end

  def send_template_email(to, template_id, template_data, opts \\ []) do
    GenServer.call(__MODULE__, {:send_template_email, to, template_id, template_data, opts})
  end

  def send_bulk_emails(recipients, subject, body, opts \\ []) do
    GenServer.call(__MODULE__, {:send_bulk_emails, recipients, subject, body, opts})
  end

  def register_template(template_id, subject_template, body_template, opts \\ []) do
    GenServer.call(
      __MODULE__,
      {:register_template, template_id, subject_template, body_template, opts}
    )
  end

  def get_email_status(_message_id, _opts \\ []) do
    # Swoosh doesn't track status for local adapter, return delivered
    {:ok, %{status: :delivered, updated_at: DateTime.utc_now()}}
  end

  @impl true
  def handle_call({:send_email, to, subject, body, opts}, _from, state) do
    email =
      new()
      |> to(to)
      |> from(Keyword.get(opts, :from, "noreply@mcp.local"))
      |> subject(subject)
      |> html_body(body)
      # Simple fallback
      |> text_body(body)

    case Mcp.Mailer.deliver(email) do
      {:ok, _metadata} ->
        Logger.info("Email sent to #{inspect(to)}")
        {:reply, {:ok, %{status: :sent}}, state}

      {:error, reason} ->
        Logger.error("Failed to send email: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:send_template_email, to, template_id, template_data, opts}, _from, state) do
    case Map.get(state.templates, template_id) do
      nil ->
        # Fallback to checking if it's a tenant-scoped template
        tenant_id = Keyword.get(opts, :tenant_id)
        full_id = "#{tenant_id}:#{template_id}"

        case Map.get(state.templates, full_id) do
          nil ->
            {:reply, {:error, :template_not_found}, state}

          template ->
            send_template(to, template, template_data, opts, state)
        end

      template ->
        send_template(to, template, template_data, opts, state)
    end
  end

  @impl true
  def handle_call({:send_bulk_emails, recipients, subject, body, opts}, _from, state) do
    # Simple iteration for now
    results =
      Enum.with_index(recipients)
      |> Enum.map(fn {recipient, index} ->
        email =
          new()
          |> to(recipient)
          |> from(Keyword.get(opts, :from, "noreply@mcp.local"))
          |> subject(subject)
          |> html_body(body)

        case Mcp.Mailer.deliver(email) do
          {:ok, _} -> {:ok, {index, :sent}}
          {:error, reason} -> {:error, {index, reason}}
        end
      end)

    {:reply, {:ok, results}, state}
  end

  @impl true
  def handle_call(
        {:register_template, template_id, subject_template, body_template, opts},
        _from,
        state
      ) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    full_template_id = "#{tenant_id}:#{template_id}"

    template = %{
      id: full_template_id,
      subject_template: subject_template,
      body_template: body_template,
      created_at: DateTime.utc_now(),
      tenant_id: tenant_id
    }

    new_templates = Map.put(state.templates, full_template_id, template)
    # Also register under short ID if global or preferred
    new_templates = Map.put(new_templates, template_id, template)

    Logger.info("Registered email template: #{full_template_id}")
    {:reply, {:ok, template}, %{state | templates: new_templates}}
  end

  defp send_template(to, template, template_data, opts, state) do
    subject = render_template(template.subject_template, template_data)
    body = render_template(template.body_template, template_data)

    # Re-use handle_call logic via internal call or just duplicate logic
    # Calling internal function to avoid GenServer overhead for self-call
    email =
      new()
      |> to(to)
      |> from(Keyword.get(opts, :from, "noreply@mcp.local"))
      |> subject(subject)
      |> html_body(body)
      |> text_body(body)

    case Mcp.Mailer.deliver(email) do
      {:ok, _} -> {:reply, {:ok, %{status: :sent}}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  defp render_template(template, data) do
    Enum.reduce(data, template, fn {key, value}, acc ->
      String.replace(acc, "{{#{key}}}", to_string(value))
    end)
  end
end
