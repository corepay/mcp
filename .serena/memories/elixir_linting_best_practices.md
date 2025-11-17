# Elixir Linting Best Practices

This memory documents common Elixir code patterns that cause lint warnings and how to avoid them.

## Unused Variables

### Pattern 1: Unused Function Parameters
When a parameter is required for function signature but not used in the body:

```elixir
# BAD - causes "variable is unused" warning
def my_function(data, opts) do
  process(data)
end

# GOOD - prefix with underscore
def my_function(data, _opts) do
  process(data)
end
```

### Pattern 2: Unused Variables in Case/With Statements
```elixir
# BAD
with {:ok, new_limits} <- check_limits(),
     result <- do_something() do
  handle_result(result)
end

# GOOD  
with {:ok, _new_limits} <- check_limits(),
     result <- do_something() do
  handle_result(result)
end
```

### Pattern 3: Unused Variables in Enum.map
```elixir
# BAD
Enum.map(items, fn {item_id, item} ->
  process_item(item)
end

# GOOD
Enum.map(items, fn {_item_id, item} ->
  process_item(item)
end
```

## Unreachable Clause Patterns

### Pattern 1: Functions That Always Return {:ok, _}
When a function always returns a success tuple, error handling is unreachable:

```elixir
# BAD - unreachable error clause
case mock_function() do  # Always returns {:ok, result}
  {:ok, result} -> handle_success(result)
  {:error, reason} -> handle_error(reason)  # Never reached!
end

# GOOD - no error handling needed
result = mock_function()  # Always returns {:ok, result}
handle_success(result)
```

### Pattern 2: Functions That Always Return :ok
When a function always returns an atom:

```elixir
# BAD
case set_value(key, value) do  # Always returns :ok
  :ok -> :success
  {:error, reason} -> :error  # Never reached!
end

# GOOD
set_value(key, value)  # Always returns :ok
:success
```

## Module Attributes

### Unused Module Attributes
Comment out unused module attributes instead of deleting them:

```elixir
# BAD - causes "module attribute was set but never used" warning
@unused_attr "some_value"

# GOOD - comment out with explanation
# @unused_attr "some_value"  # Currently unused, keep for future use
```

## Function Organization

### Grouping Clauses by Arity
Group all function clauses with the same number of arguments together:

```elixir
# BAD - causes "clauses with same name and arity should be grouped" warning
def handle_call(:msg1, _from, state) do
  # ...
end

def some_other_function() do
  # ...
end

def handle_call(:msg2, _from, state) do
  # ...
end

# GOOD
@impl true
def handle_call(:msg1, _from, state) do
  # ...
end

@impl true  
def handle_call(:msg2, _from, state) do
  # ...
end

def some_other_function() do
  # ...
end
```

## Mock Implementation Patterns

### Documenting Mock Behavior
When writing mock implementations that always succeed:

```elixir
# Document why error handling isn't needed
defp mock_service_call(_data) do
  # Mock implementation - always returns success
  # In production, this would handle real error cases
  {:ok, %{status: :success, id: generate_id()}}
end
```

### Using Parameters in Logs
When you can't use a parameter meaningfully, at least log it:

```elixir
# Instead of completely ignoring a parameter
defp process_with_unused_param(data, _unused_opts) do
  Logger.debug("Processing with opts: #{inspect(_unused_opts)}")
  process(data)
end
```

## Code Quality Checklist

Before committing code, check for:

1. [ ] No unused variables (prefix with _ if needed)
2. [ ] No unreachable error clauses for mock functions  
3. [ ] Module attributes are either used or commented out
4. [ ] Function clauses grouped by arity
5. [ ] Meaningful use of parameters or proper documentation

## Testing Considerations

- Use pattern matching to ignore unused test parameters
- Document mock function behavior in comments
- Keep unused parameters for interface consistency with underscore prefix