defmodule Phoebe.CLI do
  @moduledoc """
  Phoebe CLI - A command-line interface for working with G-expressions and the Phoebe API.

  Features:
  - Create, validate, and manipulate G-expressions
  - Interact with the Phoebe API (list, get, publish expressions)
  - Temporary and permanent file management
  - Interactive REPL mode for expression building
  """

  alias Phoebe.CLI.{ApiClient, GExpressionBuilder, FileManager, REPL}

  @version Mix.Project.config()[:version]

  def main(args) do
    case parse_args(args) do
      {command, opts} -> handle_command(command, opts)
    end
  end

  defp parse_args(args) do
    {opts, args, _} = OptionParser.parse(args,
      switches: [
        help: :boolean,
        version: :boolean,
        base_url: :string,
        temp_dir: :string,
        output: :string,
        format: :string,
        validate: :boolean,
        interactive: :boolean
      ],
      aliases: [
        h: :help,
        v: :version,
        u: :base_url,
        t: :temp_dir,
        o: :output,
        f: :format,
        i: :interactive
      ]
    )

    command = case args do
      [] -> :help
      [cmd | rest] -> {String.to_atom(cmd), rest}
    end

    {command, opts}
  end

  defp handle_command({:help, _}, _opts), do: print_help()
  defp handle_command({:version, _}, _opts), do: print_version()
  defp handle_command(:help, _opts), do: print_help()

  defp handle_command({command, args}, opts) do
    case command do
      :list -> handle_list(args, opts)
      :get -> handle_get(args, opts)
      :publish -> handle_publish(args, opts)
      :validate -> handle_validate(args, opts)
      :create -> handle_create(args, opts)
      :build -> handle_build(args, opts)
      :repl -> handle_repl(args, opts)
      :temp -> handle_temp(args, opts)
      :save -> handle_save(args, opts)
      :load -> handle_load(args, opts)
      :examples -> handle_examples(args, opts)
      :session -> handle_session(args, opts)
      :working -> handle_working(args, opts)
      :promote -> handle_promote(args, opts)
      :auto -> handle_auto_save(args, opts)
      _ ->
        IO.puts("Unknown command: #{command}")
        print_help()
        System.halt(1)
    end
  rescue
    error ->
      IO.puts("Error: #{Exception.message(error)}")
      System.halt(1)
  end

  # Command handlers

  defp handle_list(_args, opts) do
    case ApiClient.list_expressions(opts) do
      {:ok, expressions} ->
        format_expressions_list(expressions, opts)
      {:error, error} ->
        IO.puts("Error listing expressions: #{error}")
        System.halt(1)
    end
  end

  defp handle_get([name], opts) do
    case ApiClient.get_expression(name, opts) do
      {:ok, expression} ->
        format_expression_details(expression, opts)
      {:error, error} ->
        IO.puts("Error getting expression: #{error}")
        System.halt(1)
    end
  end

  defp handle_get([], _opts) do
    IO.puts("Error: Expression name required")
    IO.puts("Usage: phoebe get <expression_name>")
    System.halt(1)
  end

  defp handle_publish([file_path], opts) do
    case File.read(file_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, expression_data} ->
            case ApiClient.publish_expression(expression_data, opts) do
              {:ok, response} ->
                IO.puts("Successfully published expression: #{response["name"]}")
              {:error, error} ->
                IO.puts("Error publishing expression: #{error}")
                System.halt(1)
            end
          {:error, json_error} ->
            IO.puts("Error parsing JSON: #{inspect(json_error)}")
            System.halt(1)
        end
      {:error, file_error} ->
        IO.puts("Error reading file: #{inspect(file_error)}")
        System.halt(1)
    end
  end

  defp handle_publish([], _opts) do
    IO.puts("Error: JSON file path required")
    IO.puts("Usage: phoebe publish <json_file>")
    System.halt(1)
  end

  defp handle_validate([file_path], opts) do
    case File.read(file_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, expression_data} ->
            case Phoebe.CLI.Validator.validate_gexpression(expression_data) do
              {:ok, _validated} ->
                IO.puts("✓ G-expression is valid")
              {:error, error} ->
                IO.puts("✗ Validation error: #{error}")
                System.halt(1)
            end
          {:error, json_error} ->
            IO.puts("Error parsing JSON: #{inspect(json_error)}")
            System.halt(1)
        end
      {:error, file_error} ->
        IO.puts("Error reading file: #{inspect(file_error)}")
        System.halt(1)
    end
  end

  defp handle_validate([], _opts) do
    IO.puts("Error: JSON file path required")
    IO.puts("Usage: phoebe validate <json_file>")
    System.halt(1)
  end

  defp handle_create([type | args], opts) do
    case GExpressionBuilder.create_expression(type, args, opts) do
      {:ok, expression} ->
        output_expression(expression, opts)
      {:error, error} ->
        IO.puts("Error creating expression: #{error}")
        System.halt(1)
    end
  end

  defp handle_build(_args, opts) do
    case GExpressionBuilder.interactive_build(opts) do
      {:ok, expression} ->
        output_expression(expression, opts)
      {:error, error} ->
        IO.puts("Error building expression: #{error}")
        System.halt(1)
    end
  end

  defp handle_repl(_args, opts) do
    REPL.start(opts)
  end

  defp handle_temp([action | args], opts) do
    case action do
      "list" -> FileManager.list_temp_files(opts)
      "clean" -> FileManager.clean_temp_files(opts)
      "save" -> FileManager.save_temp_file(args, opts)
      _ ->
        IO.puts("Unknown temp action: #{action}")
        IO.puts("Available actions: list, clean, save")
        System.halt(1)
    end
  end

  defp handle_session([action | args], opts) do
    case action do
      "create" ->
        case args do
          [name] ->
            case FileManager.create_session(name, opts) do
              {:ok, session_dir} ->
                IO.puts("✓ Created session: #{name}")
                IO.puts("Directory: #{session_dir}")
              {:error, error} ->
                IO.puts("✗ Error creating session: #{error}")
                System.halt(1)
            end
          _ ->
            IO.puts("Usage: phoebe session create <name>")
            System.halt(1)
        end
      "list" -> FileManager.list_sessions(opts)
      "add" ->
        case args do
          [session_name, expr_name, expr_file] ->
            session_dir = Path.join(FileManager.get_temp_dir(opts), "session_#{FileManager.sanitize_filename(session_name)}")
            case File.read(expr_file) do
              {:ok, content} ->
                case Jason.decode(content) do
                  {:ok, gexpr} ->
                    case FileManager.add_to_session(session_dir, gexpr, expr_name, opts) do
                      {:ok, expr_path} ->
                        IO.puts("✓ Added '#{expr_name}' to session '#{session_name}'")
                        IO.puts("File: #{expr_path}")
                      {:error, error} ->
                        IO.puts("✗ Error adding to session: #{error}")
                        System.halt(1)
                    end
                  {:error, json_error} ->
                    IO.puts("✗ Invalid JSON in file: #{inspect(json_error)}")
                    System.halt(1)
                end
              {:error, file_error} ->
                IO.puts("✗ Error reading file: #{inspect(file_error)}")
                System.halt(1)
            end
          _ ->
            IO.puts("Usage: phoebe session add <session_name> <expr_name> <expr_file>")
            System.halt(1)
        end
      _ ->
        IO.puts("Unknown session action: #{action}")
        IO.puts("Available actions: create, list, add")
        System.halt(1)
    end
  end

  defp handle_working([action | args], opts) do
    case action do
      "list" -> FileManager.list_working_files(opts)
      _ ->
        IO.puts("Unknown working action: #{action}")
        IO.puts("Available actions: list")
        System.halt(1)
    end
  end

  defp handle_promote([working_file, name], opts) do
    case FileManager.promote_to_permanent(working_file, name, opts) do
      {:ok, permanent_path} ->
        IO.puts("✓ Promoted to permanent storage: #{permanent_path}")
      {:error, error} ->
        IO.puts("✗ Error promoting file: #{error}")
        System.halt(1)
    end
  end

  defp handle_promote([], _opts) do
    IO.puts("Usage: phoebe promote <working_file> <name>")
    System.halt(1)
  end

  defp handle_auto_save([expr_type | args], opts) do
    case GExpressionBuilder.create_expression(expr_type, args, opts) do
      {:ok, expression} ->
        case FileManager.auto_save_expression(expression, opts) do
          {:ok, file_path} ->
            IO.puts("✓ Auto-saved expression to: #{file_path}")
            IO.puts("Expression:")
            IO.puts(Jason.encode!(expression, pretty: true))
          {:error, error} ->
            IO.puts("✗ Error auto-saving: #{error}")
            System.halt(1)
        end
      {:error, error} ->
        IO.puts("✗ Error creating expression: #{error}")
        System.halt(1)
    end
  end

  defp handle_auto_save([], _opts) do
    IO.puts("Usage: phoebe auto <expression_type> [args...]")
    IO.puts("Example: phoebe auto lit 42")
    System.halt(1)
  end

  defp handle_save([file_path, name], opts) do
    case FileManager.save_permanent(file_path, name, opts) do
      {:ok, saved_path} ->
        IO.puts("Saved to: #{saved_path}")
      {:error, error} ->
        IO.puts("Error saving file: #{error}")
        System.halt(1)
    end
  end

  defp handle_load([name], opts) do
    case FileManager.load_permanent(name, opts) do
      {:ok, content} ->
        IO.puts(content)
      {:error, error} ->
        IO.puts("Error loading file: #{error}")
        System.halt(1)
    end
  end

  defp handle_examples(_args, _opts) do
    GExpressionBuilder.show_examples()
  end

  # Output formatting

  defp format_expressions_list(expressions, opts) do
    format = Keyword.get(opts, :format, "table")

    case format do
      "json" ->
        IO.puts(Jason.encode!(expressions, pretty: true))
      "table" ->
        print_expressions_table(expressions)
      _ ->
        IO.puts("Unknown format: #{format}")
        System.halt(1)
    end
  end

  defp format_expression_details(expression, opts) do
    format = Keyword.get(opts, :format, "pretty")

    case format do
      "json" ->
        IO.puts(Jason.encode!(expression, pretty: true))
      "pretty" ->
        print_expression_details(expression)
      _ ->
        IO.puts("Unknown format: #{format}")
        System.halt(1)
    end
  end

  defp output_expression(expression, opts) do
    output_file = Keyword.get(opts, :output)
    format = Keyword.get(opts, :format, "pretty")

    formatted = case format do
      "json" -> Jason.encode!(expression, pretty: true)
      "compact" -> Jason.encode!(expression)
      "pretty" -> format_expression_pretty(expression)
      _ -> Jason.encode!(expression, pretty: true)
    end

    case output_file do
      nil -> IO.puts(formatted)
      file_path ->
        case File.write(file_path, formatted) do
          :ok -> IO.puts("Expression saved to: #{file_path}")
          {:error, reason} ->
            IO.puts("Error writing file: #{inspect(reason)}")
            System.halt(1)
        end
    end
  end

  defp print_expressions_table(expressions) do
    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("PHOEBE G-EXPRESSIONS")
    IO.puts(String.duplicate("=", 80))

    header = String.pad_trailing("NAME", 20) <>
             String.pad_trailing("TITLE", 30) <>
             String.pad_trailing("DOWNLOADS", 12) <>
             "TAGS"
    IO.puts(header)
    IO.puts(String.duplicate("-", 80))

    Enum.each(expressions, fn expr ->
      name = String.pad_trailing(expr["name"] || "", 20)
      title = String.pad_trailing(String.slice(expr["title"] || "", 0, 28), 30)
      downloads = String.pad_trailing("#{expr["downloads_count"] || 0}", 12)
      tags = (expr["tags"] || []) |> Enum.join(", ")

      IO.puts("#{name}#{title}#{downloads}#{tags}")
    end)

    IO.puts(String.duplicate("=", 80))
    IO.puts("Found #{length(expressions)} expressions\n")
  end

  defp print_expression_details(expression) do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("G-EXPRESSION DETAILS")
    IO.puts(String.duplicate("=", 60))

    IO.puts("Name: #{expression["name"]}")
    IO.puts("Title: #{expression["title"]}")
    IO.puts("Description: #{expression["description"]}")
    IO.puts("Downloads: #{expression["downloads_count"]}")
    IO.puts("Tags: #{Enum.join(expression["tags"] || [], ", ")}")

    if expression["versions"] do
      IO.puts("\nVersions:")
      Enum.each(expression["versions"], fn version ->
        IO.puts("  • #{version["version"]} (#{version["inserted_at"]})")
      end)
    end

    if expression["expression_data"] do
      IO.puts("\nG-Expression:")
      IO.puts(Jason.encode!(expression["expression_data"], pretty: true))
    end

    IO.puts(String.duplicate("=", 60) <> "\n")
  end

  defp format_expression_pretty(expression) do
    """
    G-Expression Structure:
    #{String.duplicate("-", 40)}
    #{Jason.encode!(expression, pretty: true)}
    #{String.duplicate("-", 40)}
    Type: #{expression["g"]}
    """
  end

  defp print_help do
    IO.puts("""
    Phoebe CLI v#{@version} - G-Expression Management Tool

    USAGE:
        phoebe <command> [options] [arguments]

    COMMANDS:
      • API Operations:
        list                    List all G-expressions from the API
        get <name>              Get a specific G-expression
        publish <file>          Publish a G-expression from JSON file
        validate <file>         Validate a G-expression JSON file

      • Expression Building:
        create <type> [args]    Create a G-expression of specified type
        build                   Interactive G-expression builder
        repl                    Start interactive REPL mode
        auto <type> [args]      Create and auto-save expression locally

      • Local File Management (Primary Workflow):
        working list            List all working files (local development)
        promote <file> <name>   Promote working file to permanent storage
        temp <action>           Manage temporary files (list, clean, save)
        save <file> <name>      Save a file permanently with a name
        load <name>             Load a permanently saved file

      • Session Management:
        session create <name>   Create a new working session
        session list            List all active sessions
        session add <s> <n> <f> Add expression to session

      • Help & Examples:
        examples                Show G-expression examples
        help                    Show this help message
        version                 Show version information

    OPTIONS:
        -h, --help              Show help
        -v, --version           Show version
        -u, --base-url URL      API base URL (default: http://localhost:4000/api/v1)
        -t, --temp-dir DIR      Temporary files directory
        -o, --output FILE       Output file path
        -f, --format FORMAT     Output format (json, table, pretty, compact)
        -i, --interactive       Interactive mode
        --validate              Validate before operations

    EXAMPLES:
        phoebe list
        phoebe get identity
        phoebe create lit 42
        phoebe create lam x,y "app(ref(+), vec(ref(x), ref(y)))"
        phoebe validate my_expression.json
        phoebe publish my_expression.json
        phoebe repl

    G-EXPRESSION TYPES:
        lit <value>             Literal value
        ref <name>              Reference to a variable
        app <fn> <args>         Function application
        vec <items...>          Vector/array of expressions
        lam <params> <body>     Lambda function
        fix <expr>              Fixed-point combinator
        match <expr> <branches> Pattern matching

    For more information, visit: https://github.com/your-org/phoebe
    """)
  end

  defp print_version do
    IO.puts("Phoebe CLI v#{@version}")
  end
end