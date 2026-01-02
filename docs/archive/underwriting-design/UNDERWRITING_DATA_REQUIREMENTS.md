# Underwriting Data Requirements & API Mapping

## 1. Data Schema (Internal)

The `Mcp.Underwriting.Application` resource will store a JSONB payload
`application_data`.

### 1.1. Merchant Entity (`merchant`)

| Field         | Type   | Required | Notes                                |
| :------------ | :----- | :------- | :----------------------------------- |
| `legal_name`  | String | Yes      | Must match Tax ID                    |
| `dba_name`    | String | No       | Doing Business As                    |
| `tax_id`      | String | Yes      | EIN (US) or VAT (EU)                 |
| `entity_type` | Enum   | Yes      | `llc`, `corp`, `sole_prop`           |
| `address`     | Map    | Yes      | `{line1, city, state, zip, country}` |
| `website`     | String | Yes      | Used for Web Risk Check              |
| `mcc`         | String | Yes      | Merchant Category Code               |

### 1.2. Beneficial Owners (`owners`)

Array of objects. Required for all owners > 25%.

| Field               | Type    | Required | Notes                          |
| :------------------ | :------ | :------- | :----------------------------- |
| `first_name`        | String  | Yes      |                                |
| `last_name`         | String  | Yes      |                                |
| `dob`               | Date    | Yes      | YYYY-MM-DD                     |
| `ssn`               | String  | Yes      | Full 9 digits for credit check |
| `address`           | Map     | Yes      | Home Address                   |
| `email`             | String  | Yes      |                                |
| `phone`             | String  | Yes      |                                |
| `ownership_percent` | Integer | Yes      | 0-100                          |

## 2. Vendor API Mapping (ComplyCube)

### 2.1. Client Creation (`POST /clients`)

We map our `merchant` and `owners` to ComplyCube Clients.

- **Merchant (KYB)**:
  ```json
  {
    "type": "corporate",
    "companyName": "merchant.legal_name",
    "entityType": "merchant.entity_type",
    "registrationNumber": "merchant.tax_id"
  }
  ```
- **Owner (KYC)**:
  ```json
  {
    "type": "person",
    "email": "owner.email",
    "mobile": "owner.phone",
    "personDetails": {
      "firstName": "owner.first_name",
      "lastName": "owner.last_name",
      "dob": "owner.dob",
      "nationality": "owner.country"
    }
  }
  ```

### 2.2. Checks (`POST /checks`)

#### A. Standard Screening (AML/PEP)

- **Target**: Both Merchant (Corporate) and Owners (Person).
- **Type**: `standard_screening_check`.
- **Data Used**: Name, DOB, Country.

#### B. Document Check (ID Verification)

- **Target**: Owners.
- **Type**: `document_check`.
- **Input**: Base64 Image of Driver's License (Front/Back).

#### C. Extensive Screening (Adverse Media)

- **Target**: Merchant.
- **Type**: `extensive_screening_check`.
- **Data Used**: Company Name, Registration Number.

## 3. Risk Scoring Factors (Internal Algo)

We aggregate vendor results into a normalized `risk_score` (0-100).

| Factor                | Weight   | Source                              |
| :-------------------- | :------- | :---------------------------------- |
| **Identity Verified** | 30%      | ComplyCube (Doc Check)              |
| **Watchlist Hit**     | Critical | ComplyCube (Screening)              |
| **Credit Score**      | 20%      | Experian (via API)                  |
| **Web Presence**      | 10%      | Google Places / Website Crawl       |
| **MCC Risk**          | 15%      | Internal MCC Table (High Risk List) |
| **Geo Risk**          | 10%      | IP Address vs. Business Address     |

## 4. Document Requirements

Files to be stored in `Mcp.Documents` (S3/Minio).

1. **Government ID**: Front & Back (JPG/PNG).
2. **Voided Check**: PDF/JPG.
3. **Bank Letter**: PDF (Optional).
4. **Articles of Incorporation**: PDF (Optional for KYB).
