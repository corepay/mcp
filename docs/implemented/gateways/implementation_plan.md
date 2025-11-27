# Universal Payment Gateway Implementation Plan

## Goal Description

Create a new domain `Mcp.Payments` to act as the financial engine for a
comprehensive AI-enhanced Commerce Platform. **Context**: The platform manages
Customers, Inventory, Subscriptions, E-commerce (Carts/Orders), Invoices, Hosted
Forms, and Underwriting. **Role of Mcp.Payments**:

1. **Universal Gateway**: Normalize payment processing across providers (QorPay,
   Stripe, etc.).
2. **Data Sync**: Pass rich data (Products, Orders, Customer details) _down_ to
   the gateway if supported, to enable advanced gateway features.
3. **AI-Ready**: Capture high-fidelity transaction data to power internal AI
   services.

## User Review Required

- [ ] **Scope Alignment**: Confirm `Mcp.Payments` focuses on _processing_ and
      _syncing_, while `Mcp.Ecommerce` or `Mcp.Billing` (future/existing
      domains) handle the business logic for Orders/Subscriptions.
- [ ] **Domain Name**: `Mcp.Payments` is proposed.
- [ ] **Tech Stack**: Leveraging `Ash` for resources and `Reactor` for
      transaction orchestration.
- [ ] **Adapter Strategy**: We will define a behaviour
      `Mcp.Payments.Gateways.Adapter` that all providers must implement.
- [ ] **Persistence**: We will store normalized records of `Charges`, `Refunds`,
      etc., in our DB.

## Proposed Changes

### [NEW] Domain: Mcp.Payments

- **Location**: `lib/mcp/payments/`
- **Definition**: `lib/mcp/payments.ex` (Ash Domain)
- **Resources**:
  - `Charge` (`lib/mcp/payments/resources/charge.ex`): Represents a captured
    payment.
  - `Refund` (`lib/mcp/payments/resources/refund.ex`): Represents a refund
    against a charge.
  - `Customer` (`lib/mcp/payments/resources/customer.ex`): Represents a customer
    in the payment system.
  - `PaymentMethod` (`lib/mcp/payments/resources/payment_method.ex`): Tokenized
    payment details.
  - `GatewayTransaction` (`lib/mcp/payments/resources/gateway_transaction.ex`):
    Audit log of raw gateway interactions.

### [NEW] Orchestration Layer (Reactor)

- **Reactor**: `Mcp.Payments.TransactionReactor`
  - Purpose: Orchestrate complex payment flows (e.g., Authorize -> Capture, or
    handling 3DS redirects).
  - Steps:
    1. `validate_params`
    2. `find_or_create_customer`
    3. `tokenize_payment_method` (if needed)
    4. `execute_gateway_transaction` (via Adapter)
    5. `persist_transaction_result`
    6. `handle_webhooks` (async)

### [NEW] Adapter Layer

- **Behaviour**: `Mcp.Payments.Gateways.Adapter`
  - Callbacks: `authorize/3`, `capture/3`, `refund/3`, `void/3`,
    `create_customer/2`, `tokenize/2`.
  - **Rich Data Support**: All callbacks will accept optional `context` maps
    containing Order, Product, and Invoice data to sync with the gateway if
    supported (e.g., Level 2/3 Data for QorPay).
- **Factory**: `Mcp.Payments.Gateways.Factory` to instantiate the correct
  adapter based on configuration or request params.
- **Implementations** (Planned):
  - `Mcp.Payments.Gateways.Stripe`
  - `Mcp.Payments.Gateways.Adyen`
  - `Mcp.Payments.Gateways.Square`
  - ... (others as needed)

### [NEW] API Layer (Enterprise-Grade RESTful)

- **Router**: `lib/mcp_web/router.ex`
  - Base Scope: `/api`
- **Standards**:
  - **Idempotency**: Support `Idempotency-Key` header for all
    `POST`/`PUT`/`DELETE` requests.
  - **Pagination**: Cursor-based pagination (`starting_after`, `ending_before`,
    `limit`) for all lists.
  - **Expansion**: Support `expand[]` query param to hydrate related resources
    (e.g., `?expand[]=customer`).
  - **Versioning**: API versioning via `Mcp-Version` header (Stripe-style). No
    path versioning (e.g., `/api/v1`).
  - **Errors**: Standardized error objects (`type`, `code`, `message`, `param`,
    `doc_url`).

#### Core Payments (The "PaymentIntent" Model)

_Moving beyond simple "Charges" to support SCA/3DS and complex states._

- `POST /payment_intents` - Create an intent to collect payment.
  - Params: `amount`, `currency`, `customer`, `payment_method`, `confirm`
    (bool), `capture_method` (manual/automatic), `setup_future_usage`,
    `metadata`.
- `GET /payment_intents/:id` - Retrieve intent details.
- `POST /payment_intents/:id/confirm` - Confirm the payment (triggers 3DS if
  needed).
- `POST /payment_intents/:id/capture` - Capture an authorized amount.
- `POST /payment_intents/:id/cancel` - Cancel the intent.

#### Payment Methods (The "Wallet")

- `POST /payment_methods` - Tokenize/Create a payment method.
  - Params: `type` (card, bank_account, etc.), `billing_details`, `card` (token
    or raw data).
- `GET /payment_methods/:id` - Retrieve details.
- `POST /payment_methods/:id/attach` - Attach to a customer.
- `POST /payment_methods/:id/detach` - Detach from a customer.
- `GET /payment_methods` - List methods (filter by customer, type).

#### Customers

- `POST /customers` - Create a customer.
  - Params: `email`, `name`, `phone`, `address`, `metadata`,
    `preferred_locales`.
- `GET /customers/:id` - Retrieve customer.
- `POST /customers/:id` - Update customer.
- `DELETE /customers/:id` - Delete customer.
- `GET /customers/:id/payment_methods` - List a customer's payment methods.

#### Refunds & Disputes (Post-Payment)

- `POST /refunds` - Create a refund.
  - Params: `payment_intent`, `amount`, `reason` (duplicate, fraudulent,
    requested_by_customer), `metadata`.
- `GET /refunds/:id` - Retrieve refund.
- `GET /disputes` - List disputes (chargebacks).
- `GET /disputes/:id` - Retrieve dispute details.
- `POST /disputes/:id/close` - Close a dispute (accept liability).
- `POST /disputes/:id/evidence` - Submit evidence for a dispute.

#### Setup Intents (Save Card for Later)

- `POST /setup_intents` - Create an intent to set up a payment method for future
  use (without immediate charge).
- `POST /setup_intents/:id/confirm` - Confirm setup (handle 3DS).

#### Webhooks & Events

- `GET /events` - Poll for events (alternative to webhooks).
- `GET /events/:id` - Retrieve a specific event.
- `POST /webhook_endpoints` - Register a URL to receive events.

#### Merchant Boarding (Channels)

- `POST /boarding/merchants` - Create a new merchant account (maps to
  `new_merchant`).
  - Params: `company`, `owner`, `bank_account`, `fees`.
- `GET /boarding/merchants/:id/status` - Check underwriting status.
- `POST /boarding/merchants/:id/upload` - Upload KYC documents.

#### Hosted Forms

- `POST /forms/sessions` - Create a session for a hosted payment form.
- `GET /forms/:id` - Retrieve form configuration.

#### Utilities

- `GET /utilities/bin/:bin` - Look up card BIN information (issuing bank, type,
  country).

### [NEW] QorPay Adapter Specifics

- **Boarding**: Map `Mcp.Payments.Boarding.create_merchant` ->
  `POST /channels/new_merchant`.
- **Forms**: Map `Mcp.Payments.Forms.create_session` -> `POST /payment/forms`
  (or clone).
- **Utilities**: Map `Mcp.Payments.Utilities.lookup_bin` ->
  `GET /utilities/bin/:card_number`.
- **Reporting**: Map `Mcp.Payments.Reporting` -> `/channels/my_kpis`,
  `/channels/my_deposits`.

### [NEW] Data Models (Schema Draft)

#### Charge

```elixir
attributes do
  uuid_primary_key :id
  attribute :amount, :integer
  attribute :currency, :string
  attribute :status, :atom # :pending, :succeeded, :failed, :refunded
  attribute :provider, :atom # :stripe, :adyen, etc.
  attribute :provider_ref, :string # ID in the provider's system
  timestamps()
end
```

## Verification Plan

### Automated Tests

- **Unit**: Test `GatewayFactory` and `Adapter` behaviour.
- **Integration**: Test `Mcp.Payments` actions (create charge, etc.) with a
  `MockAdapter`.
- **API**: Test endpoints in `McpWeb.PaymentsControllerTest`.

### Manual Verification

- Since we are not coding yet, verification involves reviewing this plan and
  ensuring it meets the architectural requirements.
