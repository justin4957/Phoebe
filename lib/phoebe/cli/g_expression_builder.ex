defmodule Phoebe.CLI.GExpressionBuilder do
  @moduledoc """
  G-expression construction utilities inspired by the gexpression project.

  Provides convenient functions for creating, manipulating, and building
  G-expressions programmatically and interactively.
  """

  alias Phoebe.CLI.Validator

  @doc """
  Creates a G-expression of the specified type with given arguments.
  """
  def create_expression("lit", [value_str], _opts) do
    value = parse_value(value_str)
    {:ok, lit(value)}
  end

  def create_expression("ref", [name], _opts) do
    {:ok, ref(name)}
  end

  def create_expression("vec", items, _opts) do
    parsed_items = Enum.map(items, &parse_gexpression_or_value/1)
    {:ok, vec(parsed_items)}
  end

  def create_expression("app", [fn_str, args_str], _opts) do
    with {:ok, fn_expr} <- parse_gexpression_string(fn_str),
         {:ok, args_expr} <- parse_gexpression_string(args_str) do
      {:ok, app(fn_expr, args_expr)}
    end
  end

  def create_expression("app", [fn_str], _opts) do
    with {:ok, fn_expr} <- parse_gexpression_string(fn_str) do
      {:ok, app_single(fn_expr)}
    end
  end

  def create_expression("lam", [params_str, body_str], _opts) do
    params = String.split(params_str, ",") |> Enum.map(&String.trim/1)
    with {:ok, body_expr} <- parse_gexpression_string(body_str) do
      {:ok, lam(params, body_expr)}
    end
  end

  def create_expression("fix", [expr_str], _opts) do
    with {:ok, expr} <- parse_gexpression_string(expr_str) do
      {:ok, fix(expr)}
    end
  end

  def create_expression("match", [expr_str, branches_str], _opts) do
    with {:ok, expr} <- parse_gexpression_string(expr_str),
         {:ok, branches} <- parse_branches(branches_str) do
      {:ok, match(expr, branches)}
    end
  end

  def create_expression(type, args, _opts) do
    {:error, "Unknown expression type '#{type}' or invalid arguments: #{inspect(args)}"}
  end

  @doc """
  Interactive G-expression builder.
  """
  def interactive_build(opts \\ []) do
    IO.puts("\n=== G-Expression Builder ===")
    IO.puts("Build your G-expression step by step.")
    IO.puts("Type 'help' for available commands, 'quit' to exit.\n")

    build_loop(%{}, opts)
  end

  @doc """
  Shows example G-expressions.
  """
  def show_examples do
    examples = [
      %{
        name: "Literal Number",
        description: "A simple number literal",
        gexpr: lit(42)
      },
      %{
        name: "Literal String",
        description: "A string literal",
        gexpr: lit("hello")
      },
      %{
        name: "Variable Reference",
        description: "Reference to a variable named 'x'",
        gexpr: ref("x")
      },
      %{
        name: "Vector",
        description: "A vector containing three numbers",
        gexpr: vec([lit(1), lit(2), lit(3)])
      },
      %{
        name: "Addition Application",
        description: "Apply + function to arguments [2, 3]",
        gexpr: app(ref("+"), vec([lit(2), lit(3)]))
      },
      %{
        name: "Identity Function",
        description: "Lambda function that returns its argument",
        gexpr: lam(["x"], ref("x"))
      },
      %{
        name: "Add Function",
        description: "Lambda function that adds two numbers",
        gexpr: lam(["x", "y"], app(ref("+"), vec([ref("x"), ref("y")])))
      },
      %{
        name: "Function Application",
        description: "Apply identity function to value 42",
        gexpr: app(lam(["x"], ref("x")), lit(42))
      },
      %{
        name: "Nested Application",
        description: "Complex nested function application",
        gexpr: app(
          lam(["f", "x"], app(ref("f"), ref("x"))),
          vec([lam(["y"], app(ref("+"), vec([ref("y"), lit(1)]))), lit(5)])
        )
      },
      %{
        name: "Y Combinator",
        description: "Fixed-point combinator for recursion",
        gexpr: fix(lam(["f"], lam(["x"], app(ref("f"), app(ref("f"), ref("x"))))))
      }
    ]

    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("G-EXPRESSION EXAMPLES")
    IO.puts(String.duplicate("=", 60))

    Enum.with_index(examples, 1)
    |> Enum.each(fn {example, index} ->
      IO.puts("\n#{index}. #{example.name}")
      IO.puts("   #{example.description}")
      IO.puts("   #{Jason.encode!(example.gexpr, pretty: true)}")
    end)

    IO.puts("\n" <> String.duplicate("=", 60) <> "\n")
  end

  @doc """
  Converts a G-expression to various output formats.
  """
  def format_expression(gexpr, format \\ "pretty") do
    case format do
      "json" -> Jason.encode!(gexpr, pretty: true)
      "compact" -> Jason.encode!(gexpr)
      "pretty" -> format_pretty(gexpr)
      "elixir" -> format_elixir(gexpr)
      _ -> Jason.encode!(gexpr, pretty: true)
    end
  end

  # Core G-expression constructors (inspired by gexpression project)

  @doc "Creates a literal G-expression."
  def lit(value), do: %{"g" => "lit", "v" => value}

  @doc "Creates a reference G-expression."
  def ref(name) when is_binary(name), do: %{"g" => "ref", "v" => name}

  @doc "Creates a vector G-expression."
  def vec(elements) when is_list(elements), do: %{"g" => "vec", "v" => elements}

  @doc "Creates an application G-expression with both function and arguments."
  def app(fn_expr, args_expr), do: %{"g" => "app", "v" => %{"fn" => fn_expr, "args" => args_expr}}

  @doc "Creates an application G-expression with only function (partial application)."
  def app_single(fn_expr), do: %{"g" => "app", "v" => %{"fn" => fn_expr}}

  @doc "Creates a lambda G-expression."
  def lam(params, body) when is_list(params), do: %{"g" => "lam", "v" => %{"params" => params, "body" => body}}

  @doc "Creates a fixed-point G-expression (Y-combinator)."
  def fix(expr), do: %{"g" => "fix", "v" => expr}

  @doc "Creates a match G-expression for pattern matching."
  def match(expr, branches) when is_list(branches), do: %{"g" => "match", "v" => %{"expr" => expr, "branches" => branches}}

  # Utility functions

  @doc "Creates a branch for pattern matching."
  def branch(pattern, result), do: %{"pattern" => pattern, "result" => result}

  @doc "Validates and returns the G-expression if valid."
  def validate(gexpr) do
    Validator.validate_gexpression(gexpr)
  end

  @doc "Creates a function application chain for curried functions."
  def curry_app(fn_expr, args) when is_list(args) do
    Enum.reduce(args, fn_expr, fn arg, acc ->
      app(acc, arg)
    end)
  end

  @doc "Creates a composition of two functions."
  def compose(f, g) do
    lam(["x"], app(f, app(g, ref("x"))))
  end

  # Private helper functions

  defp build_loop(current_expr, opts) do
    case IO.gets("gx> ") |> String.trim() do
      "quit" ->
        if map_size(current_expr) > 0 do
          {:ok, current_expr}
        else
          {:error, "No expression built"}
        end

      "help" ->
        print_builder_help()
        build_loop(current_expr, opts)

      "show" ->
        IO.puts("\nCurrent expression:")
        IO.puts(format_expression(current_expr))
        build_loop(current_expr, opts)

      "validate" ->
        case validate(current_expr) do
          {:ok, _} -> IO.puts("✓ Expression is valid")
          {:error, error} -> IO.puts("✗ #{error}")
        end
        build_loop(current_expr, opts)

      "clear" ->
        IO.puts("Expression cleared.")
        build_loop(%{}, opts)

      command ->
        case parse_builder_command(command) do
          {:ok, new_expr} ->
            IO.puts("✓ Expression updated")
            build_loop(new_expr, opts)
          {:error, error} ->
            IO.puts("✗ #{error}")
            build_loop(current_expr, opts)
        end
    end
  end

  defp print_builder_help do
    IO.puts("""

    Builder Commands:
    =================
    lit <value>         Create literal (e.g., lit 42, lit "hello")
    ref <name>          Create reference (e.g., ref x)
    vec <items...>      Create vector (e.g., vec 1 2 3)
    app <fn> <args>     Create application
    lam <params> <body> Create lambda (e.g., lam x,y "ref(x)")
    fix <expr>          Create fixed-point

    Control Commands:
    =================
    show                Display current expression
    validate            Validate current expression
    clear               Clear current expression
    help                Show this help
    quit                Exit builder

    """)
  end

  defp parse_builder_command(command) do
    case String.split(command, " ", parts: 2) do
      ["lit", value] -> {:ok, lit(parse_value(value))}
      ["ref", name] -> {:ok, ref(name)}
      [type | _] -> {:error, "Command '#{type}' not fully implemented in builder mode"}
    end
  end

  defp parse_value(value_str) do
    cond do
      String.match?(value_str, ~r/^-?\d+$/) ->
        String.to_integer(value_str)
      String.match?(value_str, ~r/^-?\d*\.\d+$/) ->
        String.to_float(value_str)
      String.starts_with?(value_str, "\"") and String.ends_with?(value_str, "\"") ->
        String.slice(value_str, 1..-2)
      value_str in ["true", "false"] ->
        value_str == "true"
      true ->
        value_str
    end
  end

  defp parse_gexpression_string(str) do
    case String.trim(str) do
      "ref(" <> rest ->
        name = String.replace(rest, ~r/\)$/, "")
        {:ok, ref(String.trim(name, "\""))}
      "lit(" <> rest ->
        value_str = String.replace(rest, ~r/\)$/, "")
        {:ok, lit(parse_value(value_str))}
      json_like ->
        case Jason.decode(json_like) do
          {:ok, parsed} ->
            case Validator.validate_gexpression(parsed) do
              {:ok, valid} -> {:ok, valid}
              {:error, _} -> {:error, "Invalid G-expression: #{json_like}"}
            end
          {:error, _} -> {:error, "Could not parse: #{json_like}"}
        end
    end
  end

  defp parse_gexpression_or_value(str) do
    case parse_gexpression_string(str) do
      {:ok, gexpr} -> gexpr
      {:error, _} -> parse_value(str)
    end
  end

  defp parse_branches(_branches_str) do
    # Simplified branch parsing - would need more sophisticated parsing for real use
    {:ok, []}
  end

  defp format_pretty(gexpr) do
    case gexpr do
      %{"g" => "lit", "v" => v} -> "lit(#{inspect(v)})"
      %{"g" => "ref", "v" => v} -> "ref(#{v})"
      %{"g" => "vec", "v" => v} -> "vec(#{format_vector_pretty(v)})"
      %{"g" => "app", "v" => %{"fn" => fn_expr, "args" => args}} ->
        "app(#{format_pretty(fn_expr)}, #{format_pretty(args)})"
      %{"g" => "app", "v" => %{"fn" => fn_expr}} ->
        "app(#{format_pretty(fn_expr)})"
      %{"g" => "lam", "v" => %{"params" => params, "body" => body}} ->
        "lam([#{Enum.join(params, ", ")}], #{format_pretty(body)})"
      %{"g" => "fix", "v" => v} -> "fix(#{format_pretty(v)})"
      %{"g" => "match", "v" => %{"expr" => expr, "branches" => branches}} ->
        "match(#{format_pretty(expr)}, #{length(branches)} branches)"
      _ -> Jason.encode!(gexpr, pretty: true)
    end
  end

  defp format_elixir(gexpr) do
    case gexpr do
      %{"g" => "lit", "v" => v} -> "lit(#{inspect(v)})"
      %{"g" => "ref", "v" => v} -> "ref(\"#{v}\")"
      %{"g" => "vec", "v" => v} ->
        elements = Enum.map(v, &format_elixir_element/1) |> Enum.join(", ")
        "vec([#{elements}])"
      %{"g" => "app", "v" => %{"fn" => fn_expr, "args" => args}} ->
        "app(#{format_elixir(fn_expr)}, #{format_elixir(args)})"
      %{"g" => "lam", "v" => %{"params" => params, "body" => body}} ->
        params_str = params |> Enum.map(&"\"#{&1}\"") |> Enum.join(", ")
        "lam([#{params_str}], #{format_elixir(body)})"
      _ -> "# Complex expression - see JSON"
    end
  end

  defp format_elixir_element(%{"g" => _} = gexpr), do: format_elixir(gexpr)
  defp format_elixir_element(value), do: "lit(#{inspect(value)})"

  defp format_vector_pretty(items) do
    formatted = Enum.map(items, fn
      %{"g" => _} = gexpr -> format_pretty(gexpr)
      value -> inspect(value)
    end)
    "[#{Enum.join(formatted, ", ")}]"
  end
end