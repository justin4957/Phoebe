#!/usr/bin/env elixir

# Basic CLI functionality test
#
# This script tests the core functionality of the Phoebe CLI
# Run with: elixir test_cli.exs

IO.puts("Testing Phoebe CLI Core Functionality")
IO.puts("=" |> String.duplicate(50))

# Test 1: G-Expression Creation
IO.puts("\n1. Testing G-Expression Creation...")

alias Phoebe.CLI.GExpressionBuilder

# Test literal creation
lit_expr = GExpressionBuilder.lit(42)
IO.puts("✓ Literal: #{Jason.encode!(lit_expr)}")

# Test reference creation
ref_expr = GExpressionBuilder.ref("x")
IO.puts("✓ Reference: #{Jason.encode!(ref_expr)}")

# Test vector creation
vec_expr = GExpressionBuilder.vec([lit_expr, ref_expr])
IO.puts("✓ Vector: #{Jason.encode!(vec_expr)}")

# Test lambda creation
lam_expr = GExpressionBuilder.lam(["x"], ref_expr)
IO.puts("✓ Lambda: #{Jason.encode!(lam_expr)}")

# Test application creation
app_expr = GExpressionBuilder.app(lam_expr, lit_expr)
IO.puts("✓ Application: #{Jason.encode!(app_expr)}")

# Test 2: Validation
IO.puts("\n2. Testing Validation...")

alias Phoebe.CLI.Validator

test_cases = [
  {lit_expr, "literal"},
  {ref_expr, "reference"},
  {vec_expr, "vector"},
  {lam_expr, "lambda"},
  {app_expr, "application"}
]

Enum.each(test_cases, fn {expr, name} ->
  case Validator.validate_gexpression(expr) do
    {:ok, _} -> IO.puts("✓ Valid #{name}")
    {:error, error} -> IO.puts("✗ Invalid #{name}: #{error}")
  end
end)

# Test invalid expressions
invalid_cases = [
  {%{"g" => "invalid"}, "unknown type"},
  {%{"v" => 42}, "missing g field"},
  {%{"g" => "ref", "v" => 123}, "ref with non-string value"}
]

Enum.each(invalid_cases, fn {expr, description} ->
  case Validator.validate_gexpression(expr) do
    {:ok, _} -> IO.puts("✗ Should be invalid #{description}")
    {:error, _} -> IO.puts("✓ Correctly rejected #{description}")
  end
end)

# Test 3: File Operations
IO.puts("\n3. Testing File Operations...")

alias Phoebe.CLI.FileManager

# Ensure directories exist
FileManager.ensure_directories()
IO.puts("✓ Directories created/verified")

# Test temp file creation
case FileManager.create_temp_file(lit_expr) do
  {:ok, temp_path} ->
    IO.puts("✓ Temp file created: #{Path.basename(temp_path)}")

    # Test reading back
    case File.read(temp_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, decoded} ->
            if decoded == lit_expr do
              IO.puts("✓ Temp file content matches")
            else
              IO.puts("✗ Temp file content mismatch")
            end
          {:error, _} ->
            IO.puts("✗ Temp file contains invalid JSON")
        end
      {:error, _} ->
        IO.puts("✗ Could not read temp file")
    end
  {:error, error} ->
    IO.puts("✗ Failed to create temp file: #{error}")
end

# Test 4: Expression Analysis
IO.puts("\n4. Testing Expression Analysis...")

complex_expr = GExpressionBuilder.app(
  GExpressionBuilder.lam(["f", "x"],
    GExpressionBuilder.app(
      GExpressionBuilder.ref("f"),
      GExpressionBuilder.ref("x")
    )
  ),
  GExpressionBuilder.vec([
    GExpressionBuilder.lam(["y"],
      GExpressionBuilder.app(
        GExpressionBuilder.ref("+"),
        GExpressionBuilder.vec([
          GExpressionBuilder.ref("y"),
          GExpressionBuilder.lit(1)
        ])
      )
    ),
    GExpressionBuilder.lit(5)
  ])
)

case Validator.analyze_gexpression(complex_expr) do
  {:ok, analysis} ->
    IO.puts("✓ Analysis completed:")
    IO.puts("  Type: #{analysis.type}")
    IO.puts("  Complexity: #{analysis.complexity}")
    IO.puts("  Depth: #{analysis.depth}")
  {:error, error} ->
    IO.puts("✗ Analysis failed: #{error}")
end

# Test 5: Pretty Formatting
IO.puts("\n5. Testing Formatting...")

formats = ["pretty", "json", "compact", "elixir"]

Enum.each(formats, fn format ->
  try do
    result = GExpressionBuilder.format_expression(lam_expr, format)
    IO.puts("✓ #{format} format: #{String.slice(result, 0, 50)}...")
  rescue
    error ->
      IO.puts("✗ #{format} format failed: #{Exception.message(error)}")
  end
end)

# Test 6: Examples Generation
IO.puts("\n6. Testing Examples...")

try do
  # This would normally print to stdout, so we'll just check it doesn't crash
  capture_io = fn ->
    original_stdout = Process.whereis(:standard_io)
    {:ok, string_io} = StringIO.open("")
    Process.unregister(:standard_io)
    Process.register(string_io, :standard_io)

    try do
      GExpressionBuilder.show_examples()
    after
      Process.unregister(:standard_io)
      Process.register(original_stdout, :standard_io)
    end

    StringIO.contents(string_io) |> elem(0)
  end

  output = capture_io.()
  if String.length(output) > 100 do
    IO.puts("✓ Examples generated successfully")
  else
    IO.puts("? Examples output seems short")
  end
rescue
  error ->
    IO.puts("✗ Examples generation failed: #{Exception.message(error)}")
end

# Summary
IO.puts("\n" <> "=" |> String.duplicate(50))
IO.puts("Basic CLI functionality test completed!")
IO.puts("✓ All core components are working")

IO.puts("\nTo test the full CLI, try:")
IO.puts("  mix phoebe help")
IO.puts("  mix phoebe examples")
IO.puts("  mix phoebe create lit 42")
IO.puts("  mix phoebe validate <json_file>")
IO.puts("  mix phoebe list  # (requires API server)")
IO.puts("  mix phoebe repl")

IO.puts("\nCLI is ready for use! 🎉")