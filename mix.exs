defmodule Mcp.MixProject do
  use Mix.Project

  def project do
    [
      app: :mcp,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],

      # Code quality settings
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:ex_unit, :mix],
        ignore_warnings: ".dialyzer_ignore.exs",
        list_unused_filters: true,
        uncover_locals: true
      ],

      # Warnings as errors in production
      consolidate_protocols: Mix.env() == :prod,

      # Strict compiler options
      xref: [exclude: [Mix.Tasks.Compile]],

      # Documentation coverage
      docs: [
        main: "Mcp",
        source_ref: "main"
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Mcp.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:ex_money_sql, "~> 1.0"},
      {:ex_cldr, "~> 2.0"},
      {:bcrypt_elixir, "~> 3.0"},
      {:picosat_elixir, "~> 0.2"},
      {:absinthe_phoenix, "~> 2.0"},
      {:sourceror, "~> 1.8", only: [:dev, :test]},
      {:oban, "~> 2.0"},
      {:reactor, "~> 0.17"},
      {:open_api_spex, "~> 3.0"},
      {:ash_typescript, "~> 0.7"},
      {:usage_rules, "~> 0.1", only: [:dev]},
      {:ash_cloak, "~> 0.1"},
      {:ash_ai, "~> 0.3"},
      {:ash_paper_trail, "~> 0.5"},
      {:tidewave, "~> 0.5", only: [:dev]},
      {:live_debugger, "~> 0.4", only: [:dev]},
      {:ash_archival, "~> 2.0"},
      {:ash_double_entry, "~> 1.0"},
      {:ash_money, "~> 0.2"},
      {:ash_events, "~> 0.5"},
      {:ash_state_machine, "~> 0.2"},
      {:oban_web, "~> 2.0"},
      {:ash_oban, "~> 0.6"},
      {:ash_admin, "~> 0.13"},
      {:ash_csv, "~> 0.9"},
      {:ash_authentication_phoenix, "~> 2.0"},
      {:ash_authentication, "~> 4.0"},
      {:ash_sqlite, "~> 0.2"},
      {:ash_postgres, "~> 2.0"},
      {:ash_json_api, "~> 1.0"},
      {:ash_graphql, "~> 1.0"},
      {:ash_phoenix, "~> 2.0"},
      {:ash, "~> 3.0"},
      {:igniter, "~> 0.6", only: [:dev, :test]},
      {:phoenix, "~> 1.8.1"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:uuid, "~> 1.1"},
      {:postgrex, ">= 0.0.0"},
      {:ex_aws, "~> 2.4"},
      {:ex_aws_s3, "~> 2.4"},
      {:sweet_xml, "~> 0.7"},
      {:vaultex, "~> 1.0"},
      {:redix, "~> 1.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},

      # Testing tools
      {:ex_machina, "~> 2.7", only: :test},
      {:excoveralls, "~> 0.18", only: :test},

      # OAuth and Authentication
      {:ueberauth, "~> 0.10"},
      {:ueberauth_google, "~> 0.10"},
      {:ueberauth_github, "~> 0.8"},
      {:oauth2, "~> 2.1"},

      # 2FA and Authentication
      {:nimble_totp, "~> 0.2"},
      {:eqrcode, "~> 0.2"},
      {:cloak, "~> 1.0"},

      # JWT tokens
      {:joken, "~> 2.6"},

      # Code quality tools (dev only)
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind mcp", "esbuild mcp"],
      "assets.deploy": [
        "tailwind mcp --minify",
        "esbuild mcp --minify",
        "phx.digest"
      ],
      precommit: [
        "compile --warning-as-errors",
        "credo --strict",
        "deps.unlock --unused",
        "format --check-formatted",
        "test",
        "validate.stack"
      ],
      quality: ["compile --warning-as-errors", "credo", "dialyzer"],
      check: ["compile", "credo --strict", "dialyzer", "test", "validate.stack"]
    ]
  end
end
