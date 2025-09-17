defmodule Phoebe.CLI.FileManager do
  @moduledoc """
  File management utilities for the Phoebe CLI.

  Handles temporary file storage for working with G-expressions,
  permanent saves, and file organization.
  """

  @default_temp_dir System.tmp_dir!() |> Path.join("phoebe_cli")
  @default_save_dir Path.join([System.user_home!(), ".phoebe", "saved"])
  @temp_prefix "gexpr_"
  @temp_suffix ".json"

  def ensure_directories do
    File.mkdir_p!(@default_temp_dir)
    File.mkdir_p!(@default_save_dir)
  end

  @doc """
  Creates a temporary file with the given G-expression content.
  Returns {:ok, file_path} or {:error, reason}.
  """
  def create_temp_file(gexpr, opts \\ []) do
    ensure_directories()
    temp_dir = get_temp_dir(opts)

    timestamp = :os.system_time(:millisecond)
    random_suffix = :crypto.strong_rand_bytes(4) |> Base.encode16()
    filename = "#{@temp_prefix}#{timestamp}_#{random_suffix}#{@temp_suffix}"
    file_path = Path.join(temp_dir, filename)

    content = case Keyword.get(opts, :format, "pretty") do
      "compact" -> Jason.encode!(gexpr)
      _ -> Jason.encode!(gexpr, pretty: true)
    end

    case File.write(file_path, content) do
      :ok ->
        {:ok, file_path}
      {:error, reason} ->
        {:error, "Failed to create temp file: #{inspect(reason)}"}
    end
  end

  @doc """
  Lists all temporary files.
  """
  def list_temp_files(opts \\ []) do
    temp_dir = get_temp_dir(opts)

    case File.ls(temp_dir) do
      {:ok, files} ->
        temp_files = files
        |> Enum.filter(&String.starts_with?(&1, @temp_prefix))
        |> Enum.sort()

        print_temp_files_list(temp_files, temp_dir)

      {:error, :enoent} ->
        IO.puts("No temporary directory found.")
      {:error, reason} ->
        IO.puts("Error listing temp files: #{inspect(reason)}")
    end
  end

  @doc """
  Cleans old temporary files.
  """
  def clean_temp_files(opts \\ []) do
    temp_dir = get_temp_dir(opts)
    max_age_hours = Keyword.get(opts, :max_age, 24)
    max_age_ms = max_age_hours * 60 * 60 * 1000
    current_time = :os.system_time(:millisecond)

    case File.ls(temp_dir) do
      {:ok, files} ->
        temp_files = files
        |> Enum.filter(&String.starts_with?(&1, @temp_prefix))

        {removed, kept} = Enum.split_with(temp_files, fn file ->
          file_path = Path.join(temp_dir, file)
          case File.stat(file_path) do
            {:ok, %{mtime: mtime}} ->
              file_time_ms = :calendar.datetime_to_gregorian_seconds(mtime) * 1000
              current_time - file_time_ms > max_age_ms
            _ -> false
          end
        end)

        Enum.each(removed, fn file ->
          file_path = Path.join(temp_dir, file)
          File.rm(file_path)
        end)

        IO.puts("Cleaned #{length(removed)} files, kept #{length(kept)} files")

      {:error, :enoent} ->
        IO.puts("No temporary directory found.")
      {:error, reason} ->
        IO.puts("Error cleaning temp files: #{inspect(reason)}")
    end
  end

  @doc """
  Saves a temporary file to permanent storage.
  """
  def save_temp_file([temp_file, name], opts \\ []) do
    temp_dir = get_temp_dir(opts)
    temp_path = if String.starts_with?(temp_file, "/") do
      temp_file
    else
      Path.join(temp_dir, temp_file)
    end

    case File.read(temp_path) do
      {:ok, content} ->
        save_permanent_content(content, name, opts)
      {:error, reason} ->
        IO.puts("Error reading temp file: #{inspect(reason)}")
    end
  end

  def save_temp_file([], _opts) do
    IO.puts("Usage: phoebe temp save <temp_file> <name>")
  end

  @doc """
  Saves content to permanent storage with a given name.
  """
  def save_permanent(file_path, name, opts \\ []) do
    case File.read(file_path) do
      {:ok, content} ->
        save_permanent_content(content, name, opts)
      {:error, reason} ->
        {:error, "Failed to read file: #{inspect(reason)}"}
    end
  end

  @doc """
  Saves content directly to permanent storage.
  """
  def save_permanent_content(content, name, opts \\ []) do
    ensure_directories()
    save_dir = get_save_dir(opts)

    # Sanitize the name
    safe_name = sanitize_filename(name)
    file_path = Path.join(save_dir, "#{safe_name}.json")

    # Check if file exists and handle overwrite
    if File.exists?(file_path) and not Keyword.get(opts, :overwrite, false) do
      case IO.gets("File '#{safe_name}' already exists. Overwrite? (y/N): ") do
        response when response in ["y\n", "Y\n", "yes\n", "YES\n"] ->
          write_permanent_file(file_path, content)
        _ ->
          {:error, "Save cancelled"}
      end
    else
      write_permanent_file(file_path, content)
    end
  end

  @doc """
  Loads a permanently saved file.
  """
  def load_permanent(name, opts \\ []) do
    save_dir = get_save_dir(opts)
    safe_name = sanitize_filename(name)
    file_path = Path.join(save_dir, "#{safe_name}.json")

    case File.read(file_path) do
      {:ok, content} ->
        {:ok, content}
      {:error, :enoent} ->
        {:error, "File '#{name}' not found"}
      {:error, reason} ->
        {:error, "Failed to load file: #{inspect(reason)}"}
    end
  end

  @doc """
  Lists all permanently saved files.
  """
  def list_permanent_files(opts \\ []) do
    save_dir = get_save_dir(opts)

    case File.ls(save_dir) do
      {:ok, files} ->
        json_files = files
        |> Enum.filter(&String.ends_with?(&1, ".json"))
        |> Enum.map(&String.replace_suffix(&1, ".json", ""))
        |> Enum.sort()

        print_permanent_files_list(json_files, save_dir)

      {:error, :enoent} ->
        IO.puts("No saved files directory found.")
      {:error, reason} ->
        IO.puts("Error listing saved files: #{inspect(reason)}")
    end
  end

  @doc """
  Deletes a permanently saved file.
  """
  def delete_permanent(name, opts \\ []) do
    save_dir = get_save_dir(opts)
    safe_name = sanitize_filename(name)
    file_path = Path.join(save_dir, "#{safe_name}.json")

    case File.rm(file_path) do
      :ok ->
        IO.puts("Deleted '#{name}'")
      {:error, :enoent} ->
        IO.puts("File '#{name}' not found")
      {:error, reason} ->
        IO.puts("Error deleting file: #{inspect(reason)}")
    end
  end

  @doc """
  Opens a file in the user's default editor.
  """
  def edit_temp_file(gexpr, opts \\ []) do
    case create_temp_file(gexpr, opts) do
      {:ok, temp_path} ->
        editor = get_editor(opts)
        case System.cmd(editor, [temp_path]) do
          {_, 0} ->
            # Re-read the file after editing
            case File.read(temp_path) do
              {:ok, content} ->
                case Jason.decode(content) do
                  {:ok, edited_gexpr} ->
                    {:ok, {edited_gexpr, temp_path}}
                  {:error, json_error} ->
                    {:error, "Invalid JSON after editing: #{inspect(json_error)}"}
                end
              {:error, reason} ->
                {:error, "Failed to read edited file: #{inspect(reason)}"}
            end
          {output, exit_code} ->
            {:error, "Editor exited with code #{exit_code}: #{output}"}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Creates a workspace for building multiple expressions.
  """
  def create_workspace(name, opts \\ []) do
    ensure_directories()
    temp_dir = get_temp_dir(opts)
    workspace_dir = Path.join(temp_dir, "workspace_#{sanitize_filename(name)}")

    case File.mkdir(workspace_dir) do
      :ok ->
        # Create a metadata file
        metadata = %{
          "name" => name,
          "created_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "expressions" => []
        }

        metadata_path = Path.join(workspace_dir, ".workspace.json")
        File.write!(metadata_path, Jason.encode!(metadata, pretty: true))

        {:ok, workspace_dir}
      {:error, :eexist} ->
        {:error, "Workspace '#{name}' already exists"}
      {:error, reason} ->
        {:error, "Failed to create workspace: #{inspect(reason)}"}
    end
  end

  @doc """
  Auto-saves an expression with optional naming and returns the file path.
  This is the primary local workflow function.
  """
  def auto_save_expression(gexpr, opts \\ []) do
    ensure_directories()

    # Generate a meaningful filename based on expression type and content
    filename = generate_auto_filename(gexpr, opts)

    case create_temp_file(gexpr, opts) do
      {:ok, temp_path} ->
        # Also create a more permanent working copy if desired
        if Keyword.get(opts, :working_copy, true) do
          save_working_copy(temp_path, filename, opts)
        else
          {:ok, temp_path}
        end
      error -> error
    end
  end

  @doc """
  Creates a session for working with multiple related expressions.
  """
  def create_session(session_name, opts \\ []) do
    ensure_directories()
    temp_dir = get_temp_dir(opts)
    session_dir = Path.join(temp_dir, "session_#{sanitize_filename(session_name)}")

    case File.mkdir_p(session_dir) do
      :ok ->
        session_file = Path.join(session_dir, "session.json")
        session_data = %{
          "name" => session_name,
          "created_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "expressions" => [],
          "notes" => ""
        }

        case File.write(session_file, Jason.encode!(session_data, pretty: true)) do
          :ok -> {:ok, session_dir}
          {:error, reason} -> {:error, "Failed to create session file: #{inspect(reason)}"}
        end
      {:error, reason} -> {:error, "Failed to create session directory: #{inspect(reason)}"}
    end
  end

  @doc """
  Adds an expression to an active session.
  """
  def add_to_session(session_dir, gexpr, name, opts \\ []) do
    session_file = Path.join(session_dir, "session.json")

    case File.read(session_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, session_data} ->
            # Save the expression to a file in the session directory
            expr_file = "#{sanitize_filename(name)}.json"
            expr_path = Path.join(session_dir, expr_file)

            case File.write(expr_path, Jason.encode!(gexpr, pretty: true)) do
              :ok ->
                # Update session metadata
                new_expression = %{
                  "name" => name,
                  "file" => expr_file,
                  "type" => gexpr["g"],
                  "added_at" => DateTime.utc_now() |> DateTime.to_iso8601()
                }

                updated_expressions = [new_expression | session_data["expressions"]]
                updated_session = Map.put(session_data, "expressions", updated_expressions)

                File.write(session_file, Jason.encode!(updated_session, pretty: true))
                {:ok, expr_path}
              {:error, reason} -> {:error, "Failed to save expression: #{inspect(reason)}"}
            end
          {:error, reason} -> {:error, "Invalid session file: #{inspect(reason)}"}
        end
      {:error, reason} -> {:error, "Failed to read session: #{inspect(reason)}"}
    end
  end

  @doc """
  Lists all active sessions.
  """
  def list_sessions(opts \\ []) do
    temp_dir = get_temp_dir(opts)

    case File.ls(temp_dir) do
      {:ok, files} ->
        sessions = files
        |> Enum.filter(&String.starts_with?(&1, "session_"))
        |> Enum.map(fn session_dir ->
          session_path = Path.join(temp_dir, session_dir)
          session_file = Path.join(session_path, "session.json")

          case File.read(session_file) do
            {:ok, content} ->
              case Jason.decode(content) do
                {:ok, data} -> {session_dir, data}
                _ -> {session_dir, %{"name" => "Invalid", "expressions" => []}}
              end
            _ -> {session_dir, %{"name" => "Error", "expressions" => []}}
          end
        end)
        |> Enum.sort_by(fn {_, data} -> data["created_at"] || "" end, :desc)

        print_sessions_list(sessions, temp_dir)
      {:error, reason} ->
        IO.puts("Error listing sessions: #{inspect(reason)}")
    end
  end

  @doc """
  Creates a working copy in a more permanent location but still local.
  """
  defp save_working_copy(temp_path, filename, opts) do
    temp_dir = get_temp_dir(opts)
    working_dir = Path.join(temp_dir, "working")
    File.mkdir_p(working_dir)

    working_path = Path.join(working_dir, filename)

    case File.copy(temp_path, working_path) do
      {:ok, _bytes} -> {:ok, working_path}
      {:error, reason} -> {:error, "Failed to create working copy: #{inspect(reason)}"}
    end
  end

  @doc """
  Promotes a working file to permanent storage.
  """
  def promote_to_permanent(working_file, name, opts \\ []) do
    temp_dir = get_temp_dir(opts)
    working_dir = Path.join(temp_dir, "working")
    working_path = if String.starts_with?(working_file, "/") do
      working_file
    else
      Path.join(working_dir, working_file)
    end

    case File.read(working_path) do
      {:ok, content} ->
        case save_permanent_content(content, name, opts) do
          {:ok, permanent_path} ->
            IO.puts("✓ Promoted '#{working_file}' to permanent storage as '#{name}'")
            {:ok, permanent_path}
          error -> error
        end
      {:error, reason} ->
        {:error, "Failed to read working file: #{inspect(reason)}"}
    end
  end

  @doc """
  Lists all working files.
  """
  def list_working_files(opts \\ []) do
    temp_dir = get_temp_dir(opts)
    working_dir = Path.join(temp_dir, "working")

    case File.ls(working_dir) do
      {:ok, files} ->
        json_files = files
        |> Enum.filter(&String.ends_with?(&1, ".json"))
        |> Enum.sort_by(fn file ->
          file_path = Path.join(working_dir, file)
          case File.stat(file_path) do
            {:ok, %{mtime: mtime}} -> mtime
            _ -> {0, 0, 0}
          end
        end, :desc)

        print_working_files_list(json_files, working_dir)
      {:error, :enoent} ->
        IO.puts("No working directory found. Create some expressions first!")
      {:error, reason} ->
        IO.puts("Error listing working files: #{inspect(reason)}")
    end
  end

  # Helper functions

  def get_temp_dir(opts \\ []) do
    Keyword.get(opts, :temp_dir, @default_temp_dir)
  end

  def sanitize_filename(name) do
    name
    |> String.replace(~r/[^\w\-_.]/, "_")
    |> String.replace(~r/_+/, "_")
    |> String.trim("_")
  end

  # Private helper functions

  defp get_save_dir(opts) do
    Keyword.get(opts, :save_dir, @default_save_dir)
  end

  defp get_editor(opts) do
    Keyword.get(opts, :editor) ||
    System.get_env("EDITOR") ||
    System.get_env("VISUAL") ||
    default_editor()
  end

  defp default_editor do
    case :os.type() do
      {:win32, _} -> "notepad"
      _ -> "nano"
    end
  end


  defp write_permanent_file(file_path, content) do
    case File.write(file_path, content) do
      :ok ->
        {:ok, file_path}
      {:error, reason} ->
        {:error, "Failed to save file: #{inspect(reason)}"}
    end
  end

  defp print_temp_files_list(files, temp_dir) do
    if Enum.empty?(files) do
      IO.puts("No temporary files found.")
    else
      IO.puts("\n" <> String.duplicate("=", 60))
      IO.puts("TEMPORARY FILES")
      IO.puts(String.duplicate("=", 60))

      Enum.each(files, fn file ->
        file_path = Path.join(temp_dir, file)
        case File.stat(file_path) do
          {:ok, %{size: size, mtime: mtime}} ->
            time_str = format_time(mtime)
            size_str = format_size(size)
            IO.puts("#{String.pad_trailing(file, 35)} #{String.pad_trailing(size_str, 10)} #{time_str}")
          _ ->
            IO.puts("#{file} (stat failed)")
        end
      end)

      IO.puts(String.duplicate("=", 60))
      IO.puts("Found #{length(files)} temporary files")
      IO.puts("Directory: #{temp_dir}\n")
    end
  end

  defp print_permanent_files_list(files, save_dir) do
    if Enum.empty?(files) do
      IO.puts("No saved files found.")
    else
      IO.puts("\n" <> String.duplicate("=", 60))
      IO.puts("SAVED G-EXPRESSIONS")
      IO.puts(String.duplicate("=", 60))

      Enum.each(files, fn name ->
        file_path = Path.join(save_dir, "#{name}.json")
        case File.stat(file_path) do
          {:ok, %{size: size, mtime: mtime}} ->
            time_str = format_time(mtime)
            size_str = format_size(size)

            # Try to read and analyze the expression
            analysis = case File.read(file_path) do
              {:ok, content} ->
                case Jason.decode(content) do
                  {:ok, gexpr} ->
                    case gexpr["g"] do
                      type when is_binary(type) -> "[#{type}]"
                      _ -> "[unknown]"
                    end
                  _ -> "[invalid]"
                end
              _ -> "[error]"
            end

            IO.puts("#{String.pad_trailing(name, 25)} #{String.pad_trailing(analysis, 12)} #{String.pad_trailing(size_str, 10)} #{time_str}")
          _ ->
            IO.puts("#{name} (stat failed)")
        end
      end)

      IO.puts(String.duplicate("=", 60))
      IO.puts("Found #{length(files)} saved files")
      IO.puts("Directory: #{save_dir}\n")
    end
  end

  defp format_time({{year, month, day}, {hour, minute, second}}) do
    "#{year}-#{String.pad_leading("#{month}", 2, "0")}-#{String.pad_leading("#{day}", 2, "0")} " <>
    "#{String.pad_leading("#{hour}", 2, "0")}:#{String.pad_leading("#{minute}", 2, "0")}:#{String.pad_leading("#{second}", 2, "0")}"
  end

  defp format_size(size) when size < 1024, do: "#{size}B"
  defp format_size(size) when size < 1024 * 1024, do: "#{Float.round(size / 1024, 1)}KB"
  defp format_size(size), do: "#{Float.round(size / (1024 * 1024), 1)}MB"

  defp generate_auto_filename(gexpr, opts) do
    base_name = case gexpr do
      %{"g" => "lit", "v" => value} ->
        "lit_#{sanitize_value_for_filename(value)}"
      %{"g" => "ref", "n" => name} ->
        "ref_#{sanitize_filename(name)}"
      %{"g" => "lam", "p" => params} when is_list(params) ->
        param_str = Enum.join(params, "_")
        "lambda_#{sanitize_filename(param_str)}"
      %{"g" => "vec", "v" => items} when is_list(items) ->
        "vector_#{length(items)}_items"
      %{"g" => "app"} ->
        "application"
      %{"g" => type} ->
        "#{type}_expr"
      _ ->
        "unknown_expr"
    end

    # Add timestamp to make unique
    timestamp = :os.system_time(:millisecond)
    custom_name = Keyword.get(opts, :name)

    filename = if custom_name do
      "#{sanitize_filename(custom_name)}_#{timestamp}.json"
    else
      "#{base_name}_#{timestamp}.json"
    end

    filename
  end

  defp sanitize_value_for_filename(value) do
    case value do
      val when is_number(val) -> "#{val}"
      val when is_binary(val) -> String.slice(sanitize_filename(val), 0, 10)
      val when is_boolean(val) -> "#{val}"
      _ -> "complex"
    end
  end

  defp print_sessions_list(sessions, temp_dir) do
    if Enum.empty?(sessions) do
      IO.puts("No active sessions found.")
    else
      IO.puts("\n" <> String.duplicate("=", 70))
      IO.puts("ACTIVE SESSIONS")
      IO.puts(String.duplicate("=", 70))

      Enum.each(sessions, fn {session_dir, data} ->
        name = data["name"] || "Unknown"
        expr_count = length(data["expressions"] || [])
        created = data["created_at"] || "Unknown"

        IO.puts("#{String.pad_trailing(name, 20)} #{String.pad_trailing("#{expr_count} exprs", 12)} #{created}")
      end)

      IO.puts(String.duplicate("=", 70))
      IO.puts("Found #{length(sessions)} active sessions")
      IO.puts("Directory: #{temp_dir}\n")
    end
  end

  defp print_working_files_list(files, working_dir) do
    if Enum.empty?(files) do
      IO.puts("No working files found.")
    else
      IO.puts("\n" <> String.duplicate("=", 70))
      IO.puts("WORKING FILES (Local Development)")
      IO.puts(String.duplicate("=", 70))

      Enum.each(files, fn file ->
        file_path = Path.join(working_dir, file)
        case File.stat(file_path) do
          {:ok, %{size: size, mtime: mtime}} ->
            time_str = format_time(mtime)
            size_str = format_size(size)

            # Try to determine expression type
            type_info = case File.read(file_path) do
              {:ok, content} ->
                case Jason.decode(content) do
                  {:ok, gexpr} -> "[#{gexpr["g"] || "unknown"}]"
                  _ -> "[invalid]"
                end
              _ -> "[error]"
            end

            display_name = String.replace_suffix(file, ".json", "")
            IO.puts("#{String.pad_trailing(display_name, 30)} #{String.pad_trailing(type_info, 12)} #{String.pad_trailing(size_str, 8)} #{time_str}")
          _ ->
            IO.puts("#{file} (stat failed)")
        end
      end)

      IO.puts(String.duplicate("=", 70))
      IO.puts("Found #{length(files)} working files")
      IO.puts("Directory: #{working_dir}")
      IO.puts("Use 'phoebe promote <file> <name>' to save permanently\n")
    end
  end
end