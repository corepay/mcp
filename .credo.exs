# This file contains the configuration for Credo
#
# You can find the full list of checks by running `mix credo list`
#
#              ___________
#   __   __  __/\___\ \ \___  ______
#  |  \ /  |/\  \___  \ \  \/ /  __/
#  |  ' ' |  \ /  __/  /  /  /__
#  |  .  | /  \___  /  /  /  __/
#  \___/\/__/_____/ /__/  /____/
#
# Credo configuration

%{
  # The name of the main tools directory.
  #
  # This can be a string or a tuple with a string and a keyword list.
  #
  # {"my_tool", dir: "/path/to/my_tool"}
  #
  # This can also be a list of tools.
  #
  # [{"my_tool", dir: "/path/to/my_tool"}, {"other_tool", dir: "/path/to/other_tool"}]
  #
  # If you prefer to use a function to calculate the value, you can pass a tuple:
  # {MyModule, :my_function, [arg1, arg2]}
  #
  name: "default",

  # The directory of the source files.
  #
  # This can be a string or a tuple with a string and a keyword list.
  #
  # {"my_tool", dir: "/path/to/my_tool"}
  #
  # This can also be a list of directories.
  #
  # [{"my_tool", dir: "/path/to/my_tool"}, {"other_tool", dir: "/path/to/other_tool"}]
  #
  # If you prefer to use a function to calculate the value, you can pass a tuple:
  # {MyModule, :my_function, [arg1, arg2]}
  #
  files: %{
    #
    # You can have a value or a tuple of values for the :included key.
    #
    # included: ["lib/", "src/", "test/"],
    # included: ["lib/", "src/", "test/", "web/"],
    #
    # included: ["lib/", "src/", "test/"],
    #
    excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"],
    #
    # You can also set the file extensions you care about.
    #
    # crawlable_extensions: [".ex", ".exs", ".erl", ".hrl", ".eex", ".leex", ".heex"],
    #
    # You can also give a list of patterns you want to crawl.
    #
    # crawlable_patterns: ["*.{ex,exs,erl,hrl,eex,leex,heex}"],
    #
    # You can also give a list of patterns to exclude.
    #
    # excluded_patterns: ["*_test.exs"],
    #
    # The default values are:
    #
    included: ["lib/", "src/", "test/"],
    excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"],
    crawlable_extensions: [".ex", ".exs", ".erl", ".hrl", ".eex", ".leex", ".heex"],
    crawlable_patterns: ["*.{ex,exs,erl,hrl,eex,leex,heex}"]
  },

  #
  # The plugins to use.
  #
  # Please see `mix help credo.plugins` for more information.
  #
  plugins: [],

  #
  # The parameters for the plugins.
  #
  plugin_parameters: [],

  #
  # The language meta-specific checks to run.
  #
  #
  # For a list of language meta checks, see `mix credo list --checks-for-meta`.
  #
  language_meta_checks: [],

  #
  # The checks to run.
  #
  # For a list of all available checks, see `mix credo list`.
  #
  #
  # Checks can be enabled by name or as a tuple with the name and the options.
  #
  # `disabled: false` is the same as just writing the check name.
  #
  # Checks can also be disabled explicitly:
  #
  # disabled: [{Credo.Check.Design.TagTODO, false}, {Credo.Check.Io.Print, false}]
  #
  # Or all checks can be disabled by default and some checks can be enabled explicitly:
  #
  # enabled: [
  #   {Credo.Check.Design.TagTODO, false},
  #   {Credo.Check.Io.Print, false}
  # ]
  #
  # These are the default checks that are enabled:
  #
  enabled: [
    #
    ## Consistency Checks
    #
    {Credo.Check.Consistency.ExceptionNames, []},
    {Credo.Check.Consistency.MultiAliasImportRequireUse, []},
    {Credo.Check.Consistency.ParameterPatternMatching, []},
    {Credo.Check.Consistency.SpaceAroundOperators, []},
    {Credo.Check.Consistency.SpaceInParentheses, []},
    {Credo.Check.Consistency.TabsOrSpaces, []},

    #
    ## Design Checks
    #
    {Credo.Check.Design.AliasUsage,
     [if_nested_deeper_than: 2, if_called_more_often_than: 0, if_override: false]},
    # Disabled for now, enable later
    {Credo.Check.Design.DuplicatedCode, false},
    {Credo.Check.Design.TagTODO, false},
    {Credo.Check.Design.TagFIXME, []},

    #
    ## Readability Checks
    #
    {Credo.Check.Readability.AliasOrder, []},
    {Credo.Check.Readability.FunctionNames, []},
    {Credo.Check.Readability.LargeNumbers, []},
    {Credo.Check.Readability.MaxLineLength, [max_length: 120, ignore_comments: false]},
    {Credo.Check.Readability.ModuleAttributeNames, []},
    {Credo.Check.Readability.ModuleDoc, []},
    {Credo.Check.Readability.ModuleNames, []},
    {Credo.Check.Readability.ParenthesesInCondition, []},
    {Credo.Check.Readability.PipeIntoAnonymousFunctions, []},
    # Disabled, pipe-lets preferred
    {Credo.Check.Readability.Predicates, false},
    {Credo.Check.Readability.PreferenceList, []},
    {Credo.Check.Readability.RedundantBlankLines, []},
    {Credo.Check.Readability.Semicolons, []},
    {Credo.Check.Readability.SpaceAfterCommas, []},
    {Credo.Check.Readability.StringSigils, []},
    {Credo.Check.Readability.TrailingBlankLine, []},
    {Credo.Check.Readability.TrailingWhiteSpace, []},
    {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
    {Credo.Check.Readability.VariableNames, []},
    {Credo.Check.Readability.WithSingleClause, []},

    #
    ## Refactoring Opportunities
    #
    {Credo.Check.Refactor.ABCSize, max_size: 25, max_complexity: 5},
    {Credo.Check.Refactor.Apply, []},
    {Credo.Check.Refactor.CyclomaticComplexity, max_complexity: 8},
    {Credo.Check.Refactor.FunctionArity, []},
    {Credo.Check.Refactor.LongQuoteBlocks, []},
    {Credo.Check.Refactor.MatchInCondition, []},
    {Credo.Check.Refactor.ModuleDCSM, []},
    {Credo.Check.Refactor.NegatedConditionsInUnless, []},
    {Credo.Check.Refactor.PipeChainStart, []},
    {Credo.Check.Refactor.PipeChainSimplification, []},
    # Let rebinding is preferred in functional style
    {Credo.Check.Refactor.VariableRebinding, false},
    {Credo.Check.Refactor.WithClauses, []},

    #
    ## Warnings
    #
    {Credo.Check.Warning.ApplicationConfigInModuleAttribute, []},
    {Credo.Check.Warning.BoolOperationOnSameValues, []},
    {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
    {Credo.Check.Warning.IExPry, []},
    {Credo.Check.Warning.IoInspect, []},
    {Credo.Check.Warning.MissedFileKey, []},
    {Credo.Check.Warning.OperationOnSameValues, []},
    {Credo.Check.Warning.OperationWithConstantResult, []},
    {Credo.Check.Warning.RaiseInsideRescue, []},
    # Disabled for now
    {Credo.Check.Warning.SpecWithStruct, false},
    {Credo.Check.Warning.UnsafeExec, []},
    {Credo.Check.Warning.UnusedEnumOperation, []},
    {Credo.Check.Warning.UnusedFileOperation, []},
    {Credo.Check.Warning.UnusedRegexOperation, []},
    {Credo.Check.Warning.UnusedStringOperation, []}

    #
    ## Disabled Checks (you can enable them per file)
    #
    # {Credo.Check.Consistency.MultiAliasImportRequireUse, false},
    # {Credo.Check.Consistency.UnusedVariableNames, false},
    # {Credo.Check.Design.DuplicatedCode, false},
    # {Credo.Check.Design.SkipTestWithoutComment, false},
    # {Credo.Check.Readability.AliasOrder, false},
    # {Credo.Check.Readability.FunctionNames, false},
    # {Credo.Check.Readability.LargeNumbers, false},
    # {Credo.Check.Readability.ModuleAttributeNames, false},
    # {Credo.Check.Readability.ModuleDoc, false},
    # {Credo.Check.Readability.ModuleNames, false},
    # {Credo.Check.Readability.ParenthesesInCondition, false},
    # {Credo.Check.Readability.PipeIntoAnonymousFunctions, false},
    # {Credo.Check.Readability.PredicateFunctionNames, false},
    # {Credo.Check.Readability.Predicates, false},
    # {Credo.Check.Readability.TrailingBlankLine, false},
    # {Credo.Check.Readability.TrailingWhiteSpace, false},
    # {Credo.Check.Readability.VariableNames, false},
    # {Credo.Check.Readability.WithSingleClause, false},
    # {Credo.Check.Refactor.ABCSize, false},
    # {Credo.Check.Refactor.Apply, false},
    # {Credo.Check.Refactor.CondStatements, false},
    # {Credo.Check.Refactor.CyclomaticComplexity, false},
    # {Credo.Check.Refactor.FunctionArity, false},
    # {Credo.Check.Refactor.LongQuoteBlocks, false},
    # {Credo.Check.Refactor.MatchInCondition, false},
    # {Credo.Check.Refactor.ModuleDCSM, false},
    # {Credo.Check.Refactor.NegatedConditionsInUnless, false},
    # {Credo.Check.Refactor.PipeChainStart, false},
    # {Credo.Check.Refactor.UnlessWithElse, false},
    # {Credo.Check.Refactor.WithClauses, false},
    # {Credo.Check.Warning.IExPry, false},
    # {Credo.Check.Warning.IoInspect, false},
    # {Credo.Check.Warning.LazyLogging, false},
    # {Credo.Check.Warning.MissedFileKey, false},
    # {Credo.Check.Warning.OperationOnSameValues, false},
    # {Credo.Check.Warning.OperationWithConstantResult, false},
    # {Credo.Check.Warning.RaiseInsideRescue, false},
    # {Credo.Check.Warning.UnusedEnumOperation, false},
    # {Credo.Check.Warning.UnusedFileOperation, false},
    # {Credo.Check.Warning.UnusedRegexOperation, false},
    # {Credo.Check.Warning.UnusedStringOperation, false}
  ],

  #
  # The checks to run in disabled mode.
  #
  # For a list of all available checks, see `mix credo list`.
  #
  # Checks can be disabled by name or as a tuple with the name and the options.
  #
  # `enabled: false` is the same as just writing the check name.
  #
  # disabled: [Credo.Check.Design.DuplicatedCode, {Credo.Check.Design.TagTODO, false}]
  #
  # These are the default checks that are disabled:
  #
  disabled: [],

  #
  # You can customize the parameters of any check by adding a second element to the tuple.
  #
  # {Credo.Check.Consistency.SpaceAroundOperators, priority: :low}
  # {Credo.Check.Consistency.TabsOrSpaces, priority: :high, priority: :low}
  #

  #
  # You can also set a priority for all checks.
  #
  # priority: :low,
  #
  # Priority can be: `low, normal, high, higher`

  #
  # You can customize the strictness level of some checks.
  #
  strict: true,

  #
  # You can enable min verbosity to reduce the output.
  #
  min_priority: :normal
  # or
  # min_priority: -10,

  #
  # You can remove from `exec` using the `only` option.
  #
  # only: [Credo.Check.Consistency.ExceptionNames],

  #
  # You can also limit checks to a list of files.
  #
  # only_files: ["lib/", "test/"]
  # only_files: [~r"_test\.exs$"],

  #
  # You can parse the output of the commands in exec.
  #
  # parse_args: [
  #   strict: false,
  #   all: true,
  #   format: "oneline",
  #   files_included: ["lib/", "src/"],
  #   read_from_stdin: false,
  #   enable_disabled_checks: false,
  #   enable_strict_checks: false,
  #   explain_checks: false,
  #   min_priority: :normal,
  #   checks_tag: "some_tag"
  # ],

  #
  # You can run Credo from command line as follows:
  #
  #     mix credo [files] [options]
  #
  # Some options have equivalents in the configuration file.
  #
  # Examples:
  #
  # mix credo --strict
  # mix credo --format oneline
  # mix credo --strict --only Credo.Check.Design.DuplicatedCode
  # mix credo --files-included lib/ --files-excluded test/
  # mix credo --all --strict --format json
  #
  # There are also some "unofficial" checks that are not enabled by default.
  # You can enable them in your configuration:
  #
  # {Credo.Check.Refactor.MapInto, []},
  # {Credo.Check.Warning.MapGetUnsafe, []},
  #
  # Check `mix help credo` for more information.
  #

  #
  # Credo is able to parse output from external tools.
  #
  # See https://hexdocs.pm/credo/external_tools.html
  #
  # parse_output: [
  #   # JUnit
  #   format: "junit",
  #   file: "test-results/credo-junit.xml"
  # ]
}
