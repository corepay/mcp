# ComplyCube Data Normalization Analysis

## Overview

This document analyzes the data structures exposed by the ComplyCube API (based
on Postman collections) and proposes a normalized data model for our internal
Underwriting (UW) system.

## Key Resources & Data Structures

### 1. Clients (`/clients`)

The core entity. Can be a **Person** or a **Company**.

- **Common Fields:**
  - `type`: "person" | "company"
  - `email`: String
  - `mobile`: String
  - `telephone`: String
  - `joinedDate`: Date (YYYY-MM-DD)

- **Person Specifics (`personDetails`):**
  - `firstName`: String
  - `lastName`: String
  - `dob`: Date (YYYY-MM-DD)
  - `nationality`: ISO Country Code (e.g., "GB")

- **Company Specifics (`companyDetails`):**
  - `name`: String
  - `website`: URL String
  - `registrationNumber`: String
  - `incorporationType`: String (e.g., "private_limited_company")

### 2. Addresses (`/addresses`)

Linked to a Client.

- **Fields:**
  - `clientId`: UUID
  - `type`: String (e.g., "main")
  - `propertyNumber`: String
  - `line`: String (Street address)
  - `city`: String
  - `state`: String
  - `postalCode`: String
  - `country`: ISO Country Code
  - `fromDate`: Date

### 3. Documents (`/documents`)

Identity documents linked to a Client.

- **Fields:**
  - `clientId`: UUID
  - `type`: String (e.g., "passport", "driving_license")
  - `classification`: String (e.g., "proof_of_identity", "proof_of_address")
  - `issuingCountry`: ISO Country Code
  - **Attachments:** Front and Back images (uploaded separately).

### 4. Checks (`/checks`)

Verifications performed on a Client or Document.

- **Types Identified:**
  - `standard_screening_check` (AML)
  - `extensive_screening_check` (AML)
  - `document_check`
  - `identity_check` (Document + Live Photo)
  - `proof_of_address_check`
  - `multi_bureau_check`
  - `face_authentication_check`

- **Common Fields:**
  - `clientId`: UUID
  - `documentId`: UUID (optional, for doc checks)
  - `livePhotoId`: UUID (optional, for bio checks)
  - `type`: Enum (as above)
  - `status`: String (implied: pending, complete)
  - `outcome`: String (e.g., "clear", "attention", "confirmed")
  - `result`: JSON Object (varies by check type)

## Proposed Normalized Data Model

We should design our database to be agnostic of the specific provider where
possible, but ComplyCube's structure is a good baseline.

### Tables

#### `uw_clients`

- `id`: UUID (PK)
- `type`: Enum ('person', 'company')
- `email`: String
- `phone`: String
- `external_id`: String (ComplyCube Client ID)
- `created_at`: Timestamp
- `updated_at`: Timestamp

#### `uw_person_details`

- `client_id`: UUID (FK -> uw_clients)
- `first_name`: String
- `last_name`: String
- `dob`: Date
- `nationality`: String (ISO 2)

#### `uw_company_details`

- `client_id`: UUID (FK -> uw_clients)
- `company_name`: String
- `registration_number`: String
- `incorporation_type`: String
- `website`: String

#### `uw_addresses`

- `id`: UUID (PK)
- `client_id`: UUID (FK -> uw_clients)
- `line1`: String
- `line2`: String
- `city`: String
- `state`: String
- `postal_code`: String
- `country`: String (ISO 2)
- `type`: String ('main', 'billing', etc.)

#### `uw_documents`

- `id`: UUID (PK)
- `client_id`: UUID (FK -> uw_clients)
- `type`: String ('passport', 'drivers_license', 'utility_bill')
- `issuing_country`: String (ISO 2)
- `external_id`: String (ComplyCube Document ID)
- `status`: String ('uploaded', 'verified', 'rejected')

#### `uw_checks`

- `id`: UUID (PK)
- `client_id`: UUID (FK -> uw_clients)
- `document_id`: UUID (FK -> uw_documents, nullable)
- `type`: String ('aml_standard', 'aml_extensive', 'document', 'identity',
  'poa')
- `status`: String ('pending', 'complete', 'failed')
- `outcome`: String ('clear', 'flagged')
- `external_id`: String (ComplyCube Check ID)
- `raw_result`: JSONB (Store full provider response for audit)
- `performed_at`: Timestamp

## Implementation Strategy

1. **Client Creation:** When a user applies, create `uw_clients` + details
   record. Sync to ComplyCube immediately to get `external_id`.
2. **Document Upload:** Store metadata in `uw_documents`. Upload images to
   ComplyCube.
3. **Trigger Checks:** Create `uw_checks` record, trigger check via API, update
   `external_id`.
4. **Webhooks/Polling:** Listen for check completion to update `status` and
   `outcome` in `uw_checks`.
