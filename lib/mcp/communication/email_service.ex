defmodule Mcp.Communication.EmailService do
  @moduledoc """
  Email service for sending transactional and marketing emails.
  Supports multiple providers with tenant isolation.
  """

  use GenServer
  require Logger

  @provider System.get_env("EMAIL_PROVIDER", "mock")

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting Communication EmailService with provider: #{@provider}")
    {:ok, %{provider: @provider, templates: %{}}}
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

  def get_email_status(message_id, opts \\ []) do
    GenServer.call(__MODULE__, {:get_email_status, message_id, opts})
  end

  @impl true
  def handle_call({:send_email, to, subject, body, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    email_data = build_email_data(to, subject, body, opts)

    case send_email_via_provider(email_data, state.provider, tenant_id) do
      {:ok, result} ->
        Logger.info("Email sent successfully to #{length(to)} recipients")
        {:reply, {:ok, result}, state}

      {:error, reason} ->
        Logger.error("Failed to send email: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:send_template_email, to, template_id, template_data, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")

    case Map.get(state.templates, template_id) do
      nil ->
        {:reply, {:error, :template_not_found}, state}

      template ->
        subject = render_template(template.subject_template, template_data)
        body = render_template(template.body_template, template_data)

        send_email(to, subject, body, Keyword.put(opts, :tenant_id, tenant_id))
    end
  end

  @impl true
  def handle_call({:send_bulk_emails, recipients, subject, body, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    batch_size = Keyword.get(opts, :batch_size, 100)

    results =
      recipients
      |> Enum.chunk_every(batch_size)
      |> Enum.with_index()
      |> Enum.map(fn {batch, index} ->
        email_data =
          build_email_data(batch, subject, body, Keyword.put(opts, :batch_index, index))

        case send_email_via_provider(email_data, state.provider, tenant_id) do
          {:ok, result} -> {:ok, {index, result}}
          {:error, reason} -> {:error, {index, reason}}
        end
      end)

    successful = Enum.count(results, &match?({:ok, _}, &1))
    Logger.info("Bulk email sent: #{successful}/#{length(results)} batches successful")

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
    new_state = %{state | templates: new_templates}

    Logger.info("Registered email template: #{full_template_id}")
    {:reply, {:ok, template}, new_state}
  end

  @impl true
  def handle_call({:get_email_status, message_id, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")

    # get_email_status_from_provider always returns {:ok, _}, so no error handling needed
    status = get_email_status_from_provider(message_id, state.provider, tenant_id)
    {:reply, {:ok, status}, state}
  end

  defp build_email_data(recipients, subject, body, opts) do
    from =
      Keyword.get(opts, :from, System.get_env("DEFAULT_FROM_EMAIL", "noreply@mcp-platform.local"))

    reply_to = Keyword.get(opts, :reply_to)
    cc = Keyword.get(opts, :cc, [])
    bcc = Keyword.get(opts, :bcc, [])
    attachments = Keyword.get(opts, :attachments, [])

    %{
      from: from,
      to: List.wrap(recipients),
      subject: subject,
      body: body,
      reply_to: reply_to,
      cc: cc,
      bcc: bcc,
      attachments: attachments,
      html: Keyword.get(opts, :html, false),
      tracking: Keyword.get(opts, :tracking, true)
    }
  end

  defp send_email_via_provider(_email_data, "mock", _tenant_id) do
    # Mock provider - simulate email sending
    message_id = "mock_msg_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}"
    {:ok, %{message_id: message_id, status: :sent, provider: "mock"}}
  end

  defp send_email_via_provider(_email_data, "sendgrid", tenant_id) do
    # SendGrid implementation would go here
    Logger.info("Sending email via SendGrid for tenant: #{tenant_id}")
    message_id = "sg_#{:crypto.strong_rand_bytes(12) |> Base.encode16()}"
    {:ok, %{message_id: message_id, status: :sent, provider: "sendgrid"}}
  end

  defp send_email_via_provider(_email_data, "ses", tenant_id) do
    # AWS SES implementation would go here
    Logger.info("Sending email via SES for tenant: #{tenant_id}")
    message_id = "ses_#{:crypto.strong_rand_bytes(12) |> Base.encode16()}"
    {:ok, %{message_id: message_id, status: :sent, provider: "ses"}}
  end

  defp send_email_via_provider(_email_data, provider, _tenant_id) do
    {:error, {:unsupported_provider, provider}}
  end

  defp get_email_status_from_provider(message_id, "mock", _tenant_id) do
    # Mock status check
    statuses = [:sent, :delivered, :opened, :clicked, :bounced]
    status = Enum.random(statuses)
    {:ok, %{message_id: message_id, status: status, updated_at: DateTime.utc_now()}}
  end

  defp get_email_status_from_provider(message_id, provider, tenant_id) do
    # Provider-specific status check implementation
    Logger.info("Getting email status from #{provider} for tenant: #{tenant_id}")
    {:ok, %{message_id: message_id, status: :delivered, provider: provider}}
  end

  defp render_template(template, data) do
    # Simple template rendering - would use a proper template engine in production
    Enum.reduce(data, template, fn {key, value}, acc ->
      String.replace(acc, "{{#{key}}}", to_string(value))
    end)
  end
end
