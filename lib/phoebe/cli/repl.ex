defmodule Phoebe.CLI.REPL do
  @moduledoc """
  Interactive REPL (Read-Eval-Print Loop) for building and testing G-expressions.

  Provides an interactive environment for creating, validating, and working
  with G-expressions in real-time.
  """

  alias Phoebe.CLI.{GExpressionBuilder, Validator, ApiClient, FileManager}

  @prompt "phoebe> "
  @version Mix.Project.config()[:version]

  def start(opts \\ []) do
    print_welcome()
    FileManager.ensure_directories()

    # Initialize REPL state
    state = %{
      current_expr: nil,
      history: [],
      saved_vars: %{},
      temp_files: [],
      opts: opts
    }

    repl_loop(state)
  end

  defp repl_loop(state) do
    case IO.gets(@prompt) |> String.trim() do
      "" ->
        repl_loop(state)

      "quit" ->
        print_goodbye()
        :ok

      "exit" ->
        print_goodbye()
        :ok

      command ->
        new_state = handle_command(command, state)
        repl_loop(new_state)
    end
  rescue
    error ->
      IO.puts("Error: #{Exception.message(error)}")
      repl_loop(state)
  end

  defp handle_command("help", state) do
    print_help()
    state
  end

  defp handle_command("version", state) do
    IO.puts("Phoebe CLI v#{@version}")
    state
  end

  defp handle_command("clear", state) do
    IO.puts("Environment cleared.")
    %{state | current_expr: nil, saved_vars: %{}}
  end

  defp handle_command("show" <> rest, state) do
    case String.trim(rest) do
      "" ->
        display_current_expression(state.current_expr)
      var_name ->
        display_variable(var_name, state.saved_vars)
    end
    state
  end

  defp handle_command("validate", state) do
    case state.current_expr do
      nil ->
        IO.puts("No current expression to validate.")
      expr ->
        case Validator.validate_gexpression(expr) do
          {:ok, _} ->
            IO.puts("✓ Expression is valid")
          {:error, error} ->
            IO.puts("✗ Validation error: #{error}")
        end
    end
    state
  end

  defp handle_command("analyze", state) do
    case state.current_expr do
      nil ->
        IO.puts("No current expression to analyze.")
      expr ->
        case Validator.analyze_gexpression(expr) do
          {:ok, analysis} ->
            print_analysis(analysis)
          {:error, error} ->
            IO.puts("✗ Analysis error: #{error}")
        end
    end
    state
  end

  defp handle_command("save " <> name, state) do
    case state.current_expr do
      nil ->
        IO.puts("No current expression to save.")
        state
      expr ->
        case FileManager.save_permanent_content(Jason.encode!(expr, pretty: true), name, state.opts) do
          {:ok, file_path} ->
            IO.puts("✓ Saved to: #{file_path}")
          {:error, error} ->
            IO.puts("✗ Save error: #{error}")
        end
        state
    end
  end

  defp handle_command("load " <> name, state) do
    case FileManager.load_permanent(name, state.opts) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, expr} ->
            IO.puts("✓ Loaded '#{name}'")
            display_expression(expr)
            %{state | current_expr: expr}
          {:error, json_error} ->
            IO.puts("✗ Invalid JSON in saved file: #{inspect(json_error)}")
            state
        end
      {:error, error} ->
        IO.puts("✗ Load error: #{error}")
        state
    end
  end

  defp handle_command("var " <> assignment, state) do
    case String.split(assignment, "=", parts: 2) do
      [var_name, _value] ->
        var_name = String.trim(var_name)
        case state.current_expr do
          nil ->
            IO.puts("No current expression to assign to variable '#{var_name}'")
            state
          expr ->
            IO.puts("✓ Variable '#{var_name}' assigned")
            new_vars = Map.put(state.saved_vars, var_name, expr)
            %{state | saved_vars: new_vars}
        end
      _ ->
        IO.puts("Usage: var <name>=<current_expression>")
        IO.puts("This assigns the current expression to a variable name.")
        state
    end
  end

  defp handle_command("vars", state) do
    if map_size(state.saved_vars) == 0 do
      IO.puts("No saved variables.")
    else
      IO.puts("\nSaved Variables:")
      IO.puts(String.duplicate("-", 40))
      Enum.each(state.saved_vars, fn {name, expr} ->
        type = expr["g"] || "unknown"
        IO.puts("#{String.pad_trailing(name, 15)} [#{type}]")
      end)
      IO.puts("")
    end
    state
  end

  defp handle_command("temp" <> rest, state) do
    case String.trim(rest) do
      "" ->
        FileManager.list_temp_files(state.opts)
      "clean" ->
        FileManager.clean_temp_files(state.opts)
      _ ->
        IO.puts("Usage: temp [clean]")
    end
    state
  end

  defp handle_command("list" <> rest, state) do
    case String.trim(rest) do
      "" ->
        case ApiClient.list_expressions(state.opts) do
          {:ok, expressions} ->
            print_expressions_list(expressions)
          {:error, error} ->
            IO.puts("✗ API error: #{error}")
        end
      "saved" ->
        FileManager.list_permanent_files(state.opts)
      _ ->
        IO.puts("Usage: list [saved]")
    end
    state
  end

  defp handle_command("get " <> name, state) do
    case ApiClient.get_expression(name, state.opts) do
      {:ok, expression} ->
        expr = expression["expression_data"]
        IO.puts("✓ Retrieved '#{name}' from API")
        display_expression(expr)
        %{state | current_expr: expr}
      {:error, error} ->
        IO.puts("✗ API error: #{error}")
        state
    end
  end

  defp handle_command("publish " <> title, state) do
    case state.current_expr do
      nil ->
        IO.puts("No current expression to publish.")
        state
      expr ->
        # Create a basic expression package
        package = %{
          "name" => generate_expression_name(),
          "title" => title,
          "description" => "Created via Phoebe CLI REPL",
          "expression_data" => expr,
          "tags" => ["cli", "repl"]
        }

        case ApiClient.publish_expression(package, state.opts) do
          {:ok, response} ->
            IO.puts("✓ Published as '#{response["name"]}'")
          {:error, error} ->
            IO.puts("✗ Publish error: #{error}")
        end
        state
    end
  end

  defp handle_command("edit", state) do
    case state.current_expr do
      nil ->
        IO.puts("No current expression to edit.")
        state
      expr ->
        case FileManager.edit_temp_file(expr, state.opts) do
          {:ok, {edited_expr, temp_path}} ->
            IO.puts("✓ Expression edited")
            display_expression(edited_expr)
            new_temp_files = [temp_path | state.temp_files]
            %{state | current_expr: edited_expr, temp_files: new_temp_files}
          {:error, error} ->
            IO.puts("✗ Edit error: #{error}")
            state
        end
    end
  end

  defp handle_command("examples", state) do
    GExpressionBuilder.show_examples()
    state
  end

  defp handle_command("history", state) do
    if Enum.empty?(state.history) do
      IO.puts("No command history.")
    else
      IO.puts("\nCommand History:")
      IO.puts(String.duplicate("-", 40))
      state.history
      |> Enum.reverse()
      |> Enum.with_index(1)
      |> Enum.each(fn {cmd, index} ->
        IO.puts("#{String.pad_leading("#{index}", 3)}. #{cmd}")
      end)
      IO.puts("")
    end
    state
  end

  # G-expression construction commands
  defp handle_command("lit " <> value_str, state) do
    value = parse_value(value_str)
    expr = GExpressionBuilder.lit(value)
    IO.puts("✓ Created literal expression")
    display_expression(expr)
    new_history = [value_str | state.history]
    %{state | current_expr: expr, history: new_history}
  end

  defp handle_command("ref " <> name, state) do
    expr = GExpressionBuilder.ref(String.trim(name))
    IO.puts("✓ Created reference expression")
    display_expression(expr)
    new_history = ["ref #{name}" | state.history]
    %{state | current_expr: expr, history: new_history}
  end

  defp handle_command("vec " <> items_str, state) do
    items = String.split(items_str, ~r/\s+/)
            |> Enum.map(&parse_value_or_var(&1, state.saved_vars))
    expr = GExpressionBuilder.vec(items)
    IO.puts("✓ Created vector expression")
    display_expression(expr)
    new_history = ["vec #{items_str}" | state.history]
    %{state | current_expr: expr, history: new_history}
  end

  defp handle_command("app " <> args_str, state) do
    case String.split(args_str, " ", parts: 2) do
      [fn_str, args_str] ->
        fn_expr = resolve_reference(fn_str, state.saved_vars)
        args_expr = resolve_reference(args_str, state.saved_vars)
        expr = GExpressionBuilder.app(fn_expr, args_expr)
        IO.puts("✓ Created application expression")
        display_expression(expr)
        new_history = ["app #{args_str}" | state.history]
        %{state | current_expr: expr, history: new_history}
      [fn_str] ->
        fn_expr = resolve_reference(fn_str, state.saved_vars)
        expr = GExpressionBuilder.app_single(fn_expr)
        IO.puts("✓ Created partial application expression")
        display_expression(expr)
        new_history = ["app #{fn_str}" | state.history]
        %{state | current_expr: expr, history: new_history}
      _ ->
        IO.puts("Usage: app <function> [<arguments>]")
        state
    end
  end

  defp handle_command("lam " <> rest, state) do
    case String.split(rest, " ", parts: 2) do
      [params_str, body_str] ->
        params = String.split(params_str, ",") |> Enum.map(&String.trim/1)
        body = resolve_reference(body_str, state.saved_vars)
        expr = GExpressionBuilder.lam(params, body)
        IO.puts("✓ Created lambda expression")
        display_expression(expr)
        new_history = ["lam #{rest}" | state.history]
        %{state | current_expr: expr, history: new_history}
      _ ->
        IO.puts("Usage: lam <params> <body>")
        IO.puts("Example: lam x,y $add_var")
        state
    end
  end

  defp handle_command("fix " <> expr_str, state) do
    expr_ref = resolve_reference(expr_str, state.saved_vars)
    expr = GExpressionBuilder.fix(expr_ref)
    IO.puts("✓ Created fixed-point expression")
    display_expression(expr)
    new_history = ["fix #{expr_str}" | state.history]
    %{state | current_expr: expr, history: new_history}
  end

  defp handle_command(command, state) do
    IO.puts("Unknown command: #{command}")
    IO.puts("Type 'help' for available commands.")
    state
  end

  # Helper functions

  defp print_welcome do
    IO.puts("""

    ╔═══════════════════════════════════════════════════════════╗
    ║                    PHOEBE CLI REPL                        ║
    ║               G-Expression Workspace                      ║
    ╚═══════════════════════════════════════════════════════════╝

    Welcome to the Phoebe interactive environment!
    Type 'help' for commands or 'examples' to see G-expression samples.

    """)
  end

  defp print_goodbye do
    IO.puts("""

    ╔═══════════════════════════════════════════════════════════╗
    ║                     Goodbye!                              ║
    ║            Thank you for using Phoebe CLI                 ║
    ╚═══════════════════════════════════════════════════════════╝

    """)
  end

  defp print_help do
    IO.puts("""

    PHOEBE REPL COMMANDS
    ═══════════════════════════════════════════════════════════

    Expression Building:
    ────────────────────
    lit <value>           Create literal (lit 42, lit "hello")
    ref <name>            Create reference (ref x)
    vec <items...>        Create vector (vec 1 2 3)
    app <fn> [<args>]     Create application
    lam <params> <body>   Create lambda (lam x,y $body_var)
    fix <expr>            Create fixed-point

    Variable Management:
    ───────────────────
    var <name>=           Assign current expression to variable
    vars                  List saved variables
    show [<var>]          Display current expression or variable

    File Operations:
    ───────────────
    save <name>           Save current expression permanently
    load <name>           Load saved expression
    edit                  Edit current expression in editor
    temp [clean]          List/clean temporary files

    API Operations:
    ──────────────
    list [saved]          List expressions from API or saved files
    get <name>            Get expression from API
    publish <title>       Publish current expression to API

    Analysis & Validation:
    ─────────────────────
    validate              Validate current expression
    analyze               Analyze expression structure

    General:
    ───────
    examples              Show G-expression examples
    history               Show command history
    clear                 Clear current expression and variables
    help                  Show this help
    quit/exit             Exit REPL

    TIPS:
    • Use $variable_name to reference saved variables
    • Commands auto-save to temporary files
    • Use 'show' to see your current expression
    • All expressions are validated before operations

    """)
  end

  defp display_current_expression(nil) do
    IO.puts("No current expression set.")
  end

  defp display_current_expression(expr) do
    IO.puts("\nCurrent Expression:")
    IO.puts(String.duplicate("-", 30))
    display_expression(expr)
  end

  defp display_expression(expr) do
    IO.puts(Jason.encode!(expr, pretty: true))
    IO.puts("Type: #{expr["g"]} | Pretty: #{GExpressionBuilder.format_expression(expr, "pretty")}")
  end

  defp display_variable(var_name, saved_vars) do
    case Map.get(saved_vars, var_name) do
      nil ->
        IO.puts("Variable '#{var_name}' not found.")
      expr ->
        IO.puts("\nVariable '#{var_name}':")
        IO.puts(String.duplicate("-", 30))
        display_expression(expr)
    end
  end

  defp print_analysis(analysis) do
    IO.puts("\nExpression Analysis:")
    IO.puts(String.duplicate("-", 30))
    IO.puts("Type: #{analysis.type}")
    IO.puts("Complexity: #{analysis.complexity}")
    IO.puts("Depth: #{analysis.depth}")
    IO.puts("Structure: #{inspect(analysis.structure, pretty: true)}")
  end

  defp print_expressions_list(expressions) do
    if Enum.empty?(expressions) do
      IO.puts("No expressions found.")
    else
      IO.puts("\nAPI G-Expressions:")
      IO.puts(String.duplicate("-", 50))
      Enum.each(expressions, fn expr ->
        name = expr["name"] || "unknown"
        title = expr["title"] || "No title"
        downloads = expr["downloads_count"] || 0
        IO.puts("#{String.pad_trailing(name, 20)} #{title} (#{downloads} downloads)")
      end)
      IO.puts("")
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

  defp parse_value_or_var(str, saved_vars) do
    if String.starts_with?(str, "$") do
      var_name = String.slice(str, 1..-1)
      Map.get(saved_vars, var_name, GExpressionBuilder.ref(var_name))
    else
      parse_value(str)
    end
  end

  defp resolve_reference(str, saved_vars) do
    if String.starts_with?(str, "$") do
      var_name = String.slice(str, 1..-1)
      Map.get(saved_vars, var_name, GExpressionBuilder.ref(var_name))
    else
      case parse_value(str) do
        ^str -> GExpressionBuilder.ref(str)  # If unchanged, treat as reference
        value -> GExpressionBuilder.lit(value)  # If parsed, treat as literal
      end
    end
  end

  defp generate_expression_name do
    timestamp = :os.system_time(:millisecond)
    "cli_expr_#{timestamp}"
  end
end