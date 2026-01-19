defmodule Mcp.Underwriting.DemoSeeder do
  @moduledoc """
  Seeds comprehensive underwriting demo data for the Forensic Workbench.
  """
  alias Mcp.Accounts.User
  alias Mcp.Chat.{Conversation, Message}
  alias Mcp.Platform.{Merchant, Tenant}
  alias Mcp.Underwriting.{Activity, Application, Client, Document, RiskAssessment}
  require Ash.Query

  def run(tenant_slug \\ "acme") do
    tenant = Tenant.by_slug!(tenant_slug)
    schema = tenant.company_schema

    IO.puts("🌱 Seeding Underwriting Demo for #{tenant.name} (#{schema})...")

    # Get merchants for this tenant
    {:ok, merchants} =
      Merchant
      |> Ash.read(tenant: schema)

    for merchant <- merchants do
      seed_merchant_applications(tenant, merchant)
    end

    IO.puts("✅ Underwriting Demo Seeding Complete!")
  end

  defp seed_merchant_applications(tenant, merchant) do
    schema = tenant.company_schema
    IO.puts("  - Seeding 7 applications for #{merchant.business_name}...")

    # Get or create a merchant user to link chats to
    user = ensure_merchant_user(merchant)

    profiles = demo_profiles(merchant)

    for {profile, index} <- Enum.with_index(profiles) do
      email = profile.application_data["contact_email"]
      business_name = profile.application_data["business_name"]

      # Clean up existing demo application and its related records
      Application
      |> Ash.Query.filter(
        application_data["contact_email"] == ^email and
          application_data["business_name"] == ^business_name
      )
      |> Ash.read!(tenant: schema)
      |> Enum.each(fn app ->
        # 1. Delete associated Risk Assessment
        RiskAssessment
        |> Ash.Query.filter(application_id == ^app.id)
        |> Ash.read!(tenant: schema)
        |> Enum.each(&Ash.destroy!(&1, tenant: schema))

        # 2. Delete associated Documents
        Document
        |> Ash.Query.filter(application_id == ^app.id)
        |> Ash.read!(tenant: schema)
        |> Enum.each(&Ash.destroy!(&1, tenant: schema))

        # 3. Delete associated Activities
        Activity
        |> Ash.Query.filter(application_id == ^app.id)
        |> Ash.read!(tenant: schema)
        |> Enum.each(&Ash.destroy!(&1, tenant: schema))

        # 4. Delete associated Clients
        Client
        |> Ash.Query.filter(application_id == ^app.id)
        |> Ash.read!(tenant: schema)
        |> Enum.each(&Ash.destroy!(&1, tenant: schema))

        # 5. Delete associated Conversations and their Messages
        Conversation
        |> Ash.Query.filter(subject_id == ^app.id and subject_type == :application)
        |> Ash.read!()
        |> Enum.each(fn conv ->
          # Delete messages first
          Message
          |> Ash.Query.filter(conversation_id == ^conv.id)
          |> Ash.read!()
          |> Enum.each(&Ash.destroy!(&1))

          Ash.destroy!(conv)
        end)

        # 6. Finally delete the Application
        Ash.destroy!(app, tenant: schema)
      end)

      create_complete_application(tenant, merchant, user, profile, index)
    end
  end

  defp create_complete_application(tenant, merchant, user, profile, index) do
    schema = tenant.company_schema

    # 1. Create Application
    application = create_demo_application(schema, merchant, profile, index)

    # 2. Create Clients (KYC targets)
    create_demo_clients(schema, application, profile)

    # 3. Create Documents
    create_demo_documents(schema, application, profile)

    # 4. Create Risk Assessment if applicable
    create_demo_risk_assessment(schema, merchant, application, profile)

    # 5. Create Activity Logs
    create_demo_activity_logs(schema, application)

    # 6. Create Chat History (Atlas Concierge)
    seed_chat_history(user, application, profile.chat_messages)
  end

  defp create_demo_application(schema, merchant, profile, index) do
    Application
    |> Ash.Changeset.for_create(:create, %{
      status: profile.status,
      application_data: profile.application_data,
      healed_data: profile.healed_data,
      risk_score: profile.risk_score,
      subject_id: merchant.id,
      subject_type: :merchant
    })
    |> Ash.Changeset.force_change_attribute(
      :submitted_at,
      DateTime.utc_now() |> DateTime.add(-(index * 3600), :second)
    )
    |> Ash.create!(tenant: schema)
  end

  defp create_demo_clients(schema, application, profile) do
    Ash.create!(
      Client,
      %{
        application_id: application.id,
        email: profile.application_data["contact_email"],
        type: :person,
        person_details: %{
          "first_name" =>
            profile.application_data["contact_name"] |> String.split(" ") |> List.first(),
          "last_name" =>
            profile.application_data["contact_name"] |> String.split(" ") |> List.last(),
          "role" => "Owner"
        }
      },
      tenant: schema
    )
  end

  defp create_demo_documents(schema, application, profile) do
    for doc <- profile.documents do
      Ash.create!(Document, Map.merge(doc, %{application_id: application.id}), tenant: schema)
    end
  end

  defp create_demo_risk_assessment(_schema, _merchant, _application, %{risk_score: 0}), do: nil

  defp create_demo_risk_assessment(schema, merchant, application, profile) do
    Ash.create!(
      RiskAssessment,
      %{
        application_id: application.id,
        subject_id: merchant.id,
        subject_type: :merchant,
        score: profile.risk_score,
        recommendation: derive_recommendation(profile.status),
        factors: build_risk_factors(profile)
      },
      tenant: schema
    )
  end

  defp derive_recommendation(:approved), do: :approve
  defp derive_recommendation(:funded), do: :approve
  defp derive_recommendation(:rejected), do: :reject
  defp derive_recommendation(_), do: :manual_review

  defp build_risk_factors(profile) do
    %{
      "kyb" => %{
        "status" => if(profile.risk_score > 60, do: "clear", else: "flagged"),
        "signals" => profile.healed_data["signals"] || ["registration_valid", "tax_id_verified"],
        "verification" => profile.healed_data["verification"] || %{}
      },
      "kyc" => %{
        "status" => if(profile.risk_score > 70, do: "clear", else: "manual_review"),
        "signals" =>
          if(profile.risk_score < 40,
            do: ["mismatched_id", "sanction_check_performed"],
            else: ["id_match", "no_sanctions"]
          )
      },
      "financials" => %{
        "health" => if(profile.risk_score > 80, do: "stable", else: "volatile"),
        "risk_level" => if(profile.risk_score > 80, do: "low", else: "high")
      }
    }
  end

  defp create_demo_activity_logs(schema, application) do
    Ash.create!(
      Activity,
      %{
        application_id: application.id,
        type: :status_change,
        metadata: %{"from" => "draft", "to" => "submitted"}
      },
      tenant: schema
    )
  end

  defp seed_chat_history(_user, _application, []), do: :ok

  defp seed_chat_history(user, application, messages) do
    # Create conversation
    conversation =
      Conversation
      |> Ash.Changeset.for_create(:create_for_user, %{
        title: "Application Support: #{application.application_data["business_name"]}",
        subject_id: application.id,
        subject_type: :application,
        user_id: user.id
      })
      |> Ash.create!()

    # Create messages
    for {text, source} <- messages do
      Message
      |> Ash.Changeset.for_create(:create, %{
        text: text,
        conversation_id: conversation.id
      })
      |> Ash.Changeset.force_change_attribute(:source, source)
      |> Ash.create!()
    end
  end

  defp ensure_merchant_user(merchant) do
    email = "owner@#{merchant.slug}.local"

    case User.by_email(email) do
      {:ok, user} -> user
      _ -> User.register!(email, "Password123!", "Password123!")
    end
  end

  defp demo_profiles(_merchant) do
    [
      # 1. Funded - The "Gold Standard"
      %{
        status: :funded,
        risk_score: 98,
        application_data: %{
          "business_name" => "VINTAGE SOUL LLC",
          "dba_name" => "Vintage Soul Boutique",
          "legal_entity_type" => "LLC",
          "tax_id" => "88-2910293",
          "state_of_incorporation" => "NY",
          "established_year" => "2010",
          "industry" => "Retail - Clothing & Accessories",
          "website_url" => "https://vintagesoul.shop",
          "annual_volume" => "2,500,000",
          "avg_ticket" => "125.00",
          "contact_name" => "Sarah Weaver",
          "contact_title" => "Managing Member",
          "contact_email" => "sarah@vintagesoul.local",
          "contact_phone" => "212-555-0198",
          "business_address" => "123 Fashion Ave, New York, NY 10001",
          "bank_details" => %{
            "bank_name" => "CHASE BANK",
            "routing_number" => "021000021",
            "account_number" => "****4421",
            "account_type" => "Business Checking"
          }
        },
        healed_data: %{
          "verification" => %{
            "ein_match" => true,
            "sos_status" => "Active",
            "address_verified" => true
          },
          "signals" => ["legacy_merchant", "high_trust_score", "stable_processing_history"]
        },
        documents: [
          %{
            file_name: "Articles_of_Organization_NY.pdf",
            file_path: "uploads/docs/articles_ny.pdf",
            mime_type: "application/pdf",
            document_type: :incorporation,
            status: :verified
          },
          %{
            file_name: "Operating_Agreement_Signed.pdf",
            file_path: "uploads/docs/op_agreement.pdf",
            mime_type: "application/pdf",
            document_type: :incorporation,
            status: :verified
          },
          %{
            file_name: "Chase_Statement_Dec_2025.pdf",
            file_path: "mock/chase_dec.pdf",
            mime_type: "application/pdf",
            document_type: :bank_statement,
            status: :verified
          },
          %{
            file_name: "Owner_ID_Front.jpg",
            file_path: "mock/id_front.jpg",
            mime_type: "image/jpeg",
            document_type: :identity,
            status: :verified
          },
          %{
            file_name: "Merchant_Statement_Amex_Nov.pdf",
            file_path: "mock/amex_nov.pdf",
            mime_type: "application/pdf",
            document_type: :other,
            status: :verified
          }
        ],
        chat_messages: [
          {"Welcome to the platform! I'm Atlas. I see you're applying for an Elite tier account.",
           :agent},
          {"Yes, we're expanding and need better rates for our $2M+ volume.", :user},
          {"Understood. I've analyzed your Chase statements. Your average monthly balance of $85k is well above the requirement.",
           :agent},
          {"Excellent. Anything else needed for the Articles of Organization?", :user},
          {"No, the NY state filing is verified. Your account is now fully active and funded.",
           :agent}
        ]
      },

      # 2. Approved - Saas Expansion
      %{
        status: :approved,
        risk_score: 88,
        application_data: %{
          "business_name" => "QUANTUM DATA SYSTEMS CORP",
          "legal_entity_type" => "Corporation",
          "tax_id" => "92-1102931",
          "state_of_incorporation" => "DE",
          "established_year" => "2021",
          "industry" => "Software as a Service",
          "website_url" => "https://quantumdata.io",
          "annual_volume" => "5,800,000",
          "avg_ticket" => "450.00",
          "contact_name" => "Mark Dongle",
          "contact_title" => "CEO",
          "contact_email" => "mark@quantumdata.local",
          "contact_phone" => "415-555-0442",
          "business_address" => "442 Silicon Valley Blvd, San Jose, CA 95110",
          "bank_details" => %{
            "bank_name" => "SILICON VALLEY BANK",
            "routing_number" => "121140399",
            "account_number" => "****2291",
            "account_type" => "Business Checking"
          }
        },
        healed_data: %{
          "verification" => %{"ein_match" => true, "sos_status" => "Active"},
          "signals" => ["vc_backed", "high_growth", "technical_founder"]
        },
        documents: [
          %{
            file_name: "DE_Inc_Certificate.pdf",
            file_path: "mock/de_inc.pdf",
            mime_type: "application/pdf",
            document_type: :incorporation,
            status: :verified
          },
          %{
            file_name: "SVB_Statement_Q4.pdf",
            file_path: "mock/svb_q4.pdf",
            mime_type: "application/pdf",
            document_type: :bank_statement,
            status: :verified
          },
          %{
            file_name: "Passport_Scan.png",
            file_path: "mock/passport.png",
            mime_type: "image/png",
            document_type: :identity,
            status: :verified
          }
        ],
        chat_messages: [
          {"Hi Mark! Your DE incorporation docs look great. We're just verifying your SVB account ownership via Plaid.",
           :agent},
          {"Should be quick. We have the $5M expansion round sitting there.", :user},
          {"Verified. Your risk profile is Low-Green. Approval is complete, pending final MID provisioning.",
           :agent}
        ]
      },

      # 3. Manual Review - Restaurant Chain (Mismatched Names)
      %{
        status: :manual_review,
        risk_score: 55,
        application_data: %{
          "business_name" => "MARIOS PIZZA & BISTRO GROUP",
          "dba_name" => "The Rustic Fork",
          "legal_entity_type" => "Sole Proprietorship",
          "tax_id" => "10-2293812",
          "state_of_incorporation" => "MA",
          "established_year" => "2015",
          "industry" => "Restaurant/Bar",
          "annual_volume" => "1,200,000",
          "avg_ticket" => "45.00",
          "contact_name" => "Mario Batali",
          "contact_email" => "mario@rusticfork.local",
          "contact_phone" => "617-555-0812",
          "business_address" => "812 Seaport Blvd, Boston, MA 02210",
          "bank_details" => %{
            "bank_name" => "BANK OF AMERICA",
            "routing_number" => "011000138",
            "account_number" => "****0012"
          }
        },
        healed_data: %{
          "verification" => %{"ein_match" => false, "dba_match" => true},
          "signals" => ["name_mismatch", "missing_utility_bill", "seasonality_risk"]
        },
        documents: [
          %{
            file_name: "BofA_Statement_Nov.pdf",
            file_path: "mock/bofa_nov.pdf",
            mime_type: "application/pdf",
            document_type: :bank_statement,
            status: :pending
          },
          %{
            file_name: "Business_License_Boston.pdf",
            file_path: "mock/license_boston.pdf",
            mime_type: "application/pdf",
            document_type: :business_license,
            status: :verified
          }
        ],
        chat_messages: [
          {"Hello Chef. I noticed the business name on your application doesn't quite match the BofA account holder.",
           :agent},
          {"Ah, I'm transitioning from my personal name to the LLC. Is that a problem?", :user},
          {"It requires a manual review. Could you upload a recent utility bill in the business name?",
           :agent},
          {"I'll find it and upload today.", :user}
        ]
      },

      # 4. Rejected - High Risk / Fraudulent
      %{
        status: :rejected,
        risk_score: 15,
        application_data: %{
          "business_name" => "CRYPTOKINGZ AFFILIATE SOLUTIONS",
          "legal_entity_type" => "Limited",
          "tax_id" => "00-0000000",
          "industry" => "Consulting - Crypto/Forex",
          "annual_volume" => "12,000,000",
          "avg_ticket" => "1,200.00",
          "contact_name" => "Anon King",
          "contact_email" => "admin@cryptokingz.local",
          "business_address" => "1240 Market Street, San Francisco, CA 94102",
          "bank_details" => %{
            "bank_name" => "OFFSHORE VIRTUAL BANK"
          }
        },
        healed_data: %{
          "verification" => %{"tax_id_valid" => false, "address_type" => "Virtual Office"},
          "signals" => ["synthetic_identity", "blacklisted_ip", "high_risk_industry"]
        },
        documents: [
          %{
            file_name: "Fake_Bank_Statement.pdf",
            file_path: "mock/fake_bank.pdf",
            mime_type: "application/pdf",
            document_type: :bank_statement,
            status: :rejected
          }
        ],
        chat_messages: [
          {"My application is taking too long. I need the gateway active now.", :user},
          {"I'm currently performing a deep forensics check. Several data points in your application are inconsistent with public records.",
           :agent},
          {"This is ridiculous. I'll take my business elsewhere.", :user}
        ]
      },

      # 5. Under Review - Medical Practice
      %{
        status: :under_review,
        risk_score: 72,
        application_data: %{
          "business_name" => "BEACON HEALTHCARE PARTNERS PC",
          "legal_entity_type" => "Professional Corporation",
          "tax_id" => "55-8827162",
          "industry" => "Healthcare - Specialist",
          "established_year" => "1998",
          "annual_volume" => "3,400,000",
          "contact_name" => "Dr. Gregory House",
          "contact_email" => "house@beaconhealth.local",
          "business_address" => "500 Medical Plaza, Princeton, NJ 08540",
          "bank_details" => %{
            "bank_name" => "WELLS FARGO",
            "routing_number" => "121000248",
            "account_number" => "****9912"
          }
        },
        healed_data: %{
          "verification" => %{"medical_license_active" => true, "npi_verified" => true},
          "signals" => ["low_fraud_risk", "high_compliance_vertical"]
        },
        documents: [
          %{
            file_name: "Medical_Board_Certificate.pdf",
            file_path: "mock/medical_cert.pdf",
            mime_type: "application/pdf",
            document_type: :business_license,
            status: :verified
          },
          %{
            file_name: "WF_Statement_M1.pdf",
            file_path: "mock/wf_m1.pdf",
            mime_type: "application/pdf",
            document_type: :bank_statement,
            status: :verified
          }
        ],
        chat_messages: [
          {"Good morning Dr. House. I've successfully verified your NPI and Medical Board certification.",
           :agent},
          {"Good. We need the new terminal for the patient portal by Monday.", :user},
          {"I'm accelerating the final manual approval for professional services. Stay tuned.",
           :agent}
        ]
      },

      # 6. More Info Required - Stalled Construction
      %{
        status: :more_info_required,
        risk_score: 42,
        application_data: %{
          "business_name" => "IRON & OAK CUSTOM CONSTRUCTION",
          "legal_entity_type" => "LLC",
          "tax_id" => "33-4455661",
          "industry" => "General Contractor",
          "annual_volume" => "900,000",
          "contact_name" => "Jack Hammer",
          "contact_email" => "jack@ironoack.local",
          "business_address" => "42 Industrial Way, Denver, CO 80205",
          "bank_details" => %{
            "bank_name" => "FIRST COLORADO BANK"
          }
        },
        healed_data: %{
          "verification" => %{"credit_score" => 640},
          "signals" => [
            "missing_tax_returns",
            "lapsed_insurance",
            "high_chargeback_risk_vertical"
          ]
        },
        documents: [
          %{
            file_name: "CO_LLC_Papers.pdf",
            file_path: "mock/co_llc.pdf",
            mime_type: "application/pdf",
            document_type: :incorporation,
            status: :verified
          }
        ],
        chat_messages: [
          {"Hi Jack, I've reviewed your CO filings, but I'm still missing your 2023 Corporate Tax Returns.",
           :agent},
          {"Our CPA is still finishing them up. Can we use 2022?", :user},
          {"Given the industry, our underwriters require the most recent fiscal year to set your processing limits.",
           :agent}
        ]
      },

      # 7. Under Review - Tech Shop
      %{
        status: :under_review,
        risk_score: 68,
        application_data: %{
          "business_name" => "NEON NEBULA DESIGNS",
          "legal_entity_type" => "Sole Proprietorship",
          "tax_id" => "11-2233445",
          "industry" => "Digital Goods/Design",
          "annual_volume" => "250,000",
          "contact_name" => "Sasha Vibe",
          "contact_email" => "vibe@neonnebula.local",
          "business_address" => "777 Neon Way, Austin, TX 78701",
          "bank_details" => %{
            "bank_name" => "MERCURY BANK"
          }
        },
        healed_data: %{
          "verification" => %{"identity_match" => true},
          "signals" => ["modern_banking_stack", "low_tenure", "ecom_specialist"]
        },
        documents: [
          %{
            file_name: "Mercury_Initial_Funding.pdf",
            file_path: "mock/mercury_init.pdf",
            mime_type: "application/pdf",
            document_type: :bank_statement,
            status: :verified
          }
        ],
        chat_messages: [
          {"Hi Sasha! Welcome to the platform. Your Mercury bank connection is active.", :agent},
          {"Awesome. I'm ready to start selling my digital brush packs.", :user},
          {"I'm reviewing your terms of service to ensure digital delivery compliance.", :agent}
        ]
      }
    ]
  end
end
