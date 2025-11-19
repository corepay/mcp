# Coveralls configuration
[
  # Output format
  output_dir: "cover",
  output_file: "coveralls.json",

  # Coverage requirements
  minimum_coverage: 80,

  # Skip files that don't need coverage
  skip_files: [
    "test/",
    "_build/",
    "deps/",
    "priv/repo/",
    "lib/mcp_web/telemetry.ex",
    "lib/mcp_web/endpoint.ex"
  ],

  # Include only application files
  include_files: [
    "lib/"
  ],

  # Coverage thresholds for different types of files
  coverage_thresholds: %{
    "lib/mcp/core/": 90,
    "lib/mcp/": 80,
    "lib/mcp_web/": 75
  },

  # Report coverage by module
  coverage_by_file: true,

  # Filter coverage by module patterns
  filter_by: [
    {".*", nil} # Default: include all modules
  ],

  # Ignore files with specific patterns
  ignore_files: [
    ~r"/test/",
    ~r"/_build/",
    ~r"/deps/",
    ~r"/priv/",
    ~r"test/support/",
    ~r"_test.exs$",
    ~r"/web/channels/",
    ~r"/web/telemetry.ex"
  ],

  # Print coverage information
  print_summary: true,
  print_files: true,

  # HTML coverage report
  html_report: true,

  # Console options
  console_output: true
]