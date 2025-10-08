defmodule Phoebe.CLI.Validator do
  @moduledoc """
  G-expression validation functionality adapted from Melas project.

  Provides comprehensive validation for G-expression structures to ensure
  they conform to the JSON G-expression specification before API operations.
  """

  # Core G-expression type validators
  defmodule LiteralExpr do
    def valid?(%{"g" => "lit", "v" => _}), do: true
    def valid?(_), do: false
  end

  defmodule ReferenceExpr do
    def valid?(%{"g" => "ref", "v" => v}) when is_binary(v), do: true
    def valid?(_), do: false
  end

  defmodule VectorExpr do
    def valid?(%{"g" => "vec", "v" => v}) when is_list(v), do: true
    def valid?(_), do: false
  end

  defmodule ApplicationExpr do
    def valid?(%{"g" => "app", "v" => %{"fn" => fn_expr}}) do
      Phoebe.CLI.Validator.is_valid_gexpression?(fn_expr)
    end

    def valid?(_), do: false
  end

  defmodule LambdaExpr do
    def valid?(%{"g" => "lam", "v" => %{"params" => params, "body" => body}})
        when is_list(params) do
      Enum.all?(params, &is_binary/1) and Phoebe.CLI.Validator.is_valid_gexpression?(body)
    end

    def valid?(_), do: false
  end

  defmodule FixpointExpr do
    def valid?(%{"g" => "fix", "v" => v}) do
      Phoebe.CLI.Validator.is_valid_gexpression?(v)
    end

    def valid?(_), do: false
  end

  defmodule MatchExpr do
    def valid?(%{"g" => "match", "v" => %{"expr" => expr, "branches" => branches}})
        when is_list(branches) do
      Phoebe.CLI.Validator.is_valid_gexpression?(expr) and
        Enum.all?(branches, &Phoebe.CLI.Validator.valid_branch?/1)
    end

    def valid?(_), do: false
  end

  # Main validation API

  @doc """
  Validates a G-expression structure.
  Returns {:ok, gexpr} if valid, {:error, reason} if invalid.
  """
  def validate_gexpression(gexpr) when is_map(gexpr) do
    case is_valid_gexpression?(gexpr) do
      true -> {:ok, gexpr}
      false -> {:error, build_validation_error(gexpr)}
    end
  end

  def validate_gexpression(json_string) when is_binary(json_string) do
    case Jason.decode(json_string) do
      {:ok, parsed} -> validate_gexpression(parsed)
      {:error, decode_error} -> {:error, "Invalid JSON: #{inspect(decode_error)}"}
    end
  end

  def validate_gexpression(_invalid) do
    {:error, "G-expression must be a JSON object or valid JSON string"}
  end

  @doc """
  Validates a complete expression package with metadata.
  """
  def validate_expression_package(
        %{"name" => name, "title" => title, "expression_data" => gexpr} = package
      )
      when is_binary(name) and is_binary(title) do
    case validate_gexpression(gexpr) do
      {:ok, validated_gexpr} ->
        {:ok, Map.put(package, "expression_data", validated_gexpr)}

      {:error, reason} ->
        {:error, "Invalid expression_data: #{reason}"}
    end
  end

  def validate_expression_package(%{"gexpression" => gexpr} = package) do
    # Legacy format support
    case validate_gexpression(gexpr) do
      {:ok, validated_gexpr} ->
        {:ok, Map.put(package, "gexpression", validated_gexpr)}

      {:error, reason} ->
        {:error, "Invalid gexpression: #{reason}"}
    end
  end

  def validate_expression_package(gexpr) do
    # Direct G-expression format
    validate_gexpression(gexpr)
  end

  @doc """
  Checks if a G-expression is structurally valid.
  """
  def is_valid_gexpression?(%{"g" => g_type} = expr) do
    case g_type do
      "lit" -> LiteralExpr.valid?(expr)
      "ref" -> ReferenceExpr.valid?(expr)
      "vec" -> VectorExpr.valid?(expr) and valid_vector_contents?(expr["v"])
      "app" -> ApplicationExpr.valid?(expr) and valid_application_args?(expr["v"])
      "lam" -> LambdaExpr.valid?(expr)
      "fix" -> FixpointExpr.valid?(expr)
      "match" -> MatchExpr.valid?(expr)
      _ -> false
    end
  end

  def is_valid_gexpression?(_), do: false

  @doc """
  Validates and provides detailed analysis of a G-expression.
  """
  def analyze_gexpression(gexpr) do
    case validate_gexpression(gexpr) do
      {:ok, valid_gexpr} ->
        analysis = %{
          type: valid_gexpr["g"],
          structure: analyze_structure(valid_gexpr),
          complexity: calculate_complexity(valid_gexpr),
          depth: calculate_depth(valid_gexpr)
        }

        {:ok, analysis}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Provides suggestions for fixing invalid G-expressions.
  """
  def suggest_fixes(gexpr) do
    case validate_gexpression(gexpr) do
      {:ok, _} -> []
      {:error, reason} -> generate_suggestions(gexpr, reason)
    end
  end

  # Private helper functions

  defp valid_vector_contents?(items) when is_list(items) do
    Enum.all?(items, fn item ->
      case item do
        %{"g" => _} -> is_valid_gexpression?(item)
        # Allow non-gexpression items in vectors
        _ -> true
      end
    end)
  end

  defp valid_application_args?(%{"fn" => fn_expr} = app_data) do
    fn_valid = is_valid_gexpression?(fn_expr)

    args_valid =
      case Map.get(app_data, "args") do
        # Args are optional
        nil -> true
        args -> is_valid_gexpression?(args)
      end

    fn_valid and args_valid
  end

  defp valid_application_args?(_), do: false

  def valid_branch?(%{"pattern" => _, "result" => result}) do
    is_valid_gexpression?(result)
  end

  def valid_branch?(_), do: false

  defp analyze_structure(%{"g" => g_type, "v" => v}) do
    case g_type do
      "lit" ->
        %{type: :literal, value_type: typeof(v)}

      "ref" ->
        %{type: :reference, name: v}

      "vec" ->
        %{type: :vector, length: length(v), elements: Enum.map(v, &analyze_element/1)}

      "app" ->
        %{
          type: :application,
          function: analyze_element(v["fn"]),
          args: analyze_element(v["args"])
        }

      "lam" ->
        %{type: :lambda, arity: length(v["params"]), params: v["params"]}

      "fix" ->
        %{type: :fixpoint, expr: analyze_element(v)}

      "match" ->
        %{type: :match, branches: length(v["branches"])}

      _ ->
        %{type: :unknown}
    end
  end

  defp analyze_element(%{"g" => _} = gexpr), do: analyze_structure(gexpr)
  defp analyze_element(other), do: %{type: :literal, value: other}

  defp calculate_complexity(%{"g" => g_type, "v" => v}) do
    base_complexity = 1

    case g_type do
      "lit" ->
        base_complexity

      "ref" ->
        base_complexity

      "vec" ->
        base_complexity + Enum.sum(Enum.map(v, &calculate_element_complexity/1))

      "app" ->
        fn_complexity = calculate_element_complexity(v["fn"])

        args_complexity =
          case v["args"] do
            nil -> 0
            args -> calculate_element_complexity(args)
          end

        base_complexity + fn_complexity + args_complexity

      "lam" ->
        base_complexity + calculate_element_complexity(v["body"])

      "fix" ->
        base_complexity + calculate_element_complexity(v)

      "match" ->
        expr_complexity = calculate_element_complexity(v["expr"])

        branches_complexity =
          Enum.sum(
            Enum.map(v["branches"], fn branch ->
              calculate_element_complexity(branch["result"])
            end)
          )

        base_complexity + expr_complexity + branches_complexity

      _ ->
        base_complexity
    end
  end

  defp calculate_element_complexity(%{"g" => _} = gexpr), do: calculate_complexity(gexpr)
  defp calculate_element_complexity(_), do: 0

  defp calculate_depth(%{"g" => g_type, "v" => v}) do
    case g_type do
      "lit" ->
        1

      "ref" ->
        1

      "vec" ->
        1 + (v |> Enum.map(&calculate_element_depth/1) |> Enum.max(default: 0))

      "app" ->
        fn_depth = calculate_element_depth(v["fn"])

        args_depth =
          case v["args"] do
            nil -> 0
            args -> calculate_element_depth(args)
          end

        1 + max(fn_depth, args_depth)

      "lam" ->
        1 + calculate_element_depth(v["body"])

      "fix" ->
        1 + calculate_element_depth(v)

      "match" ->
        expr_depth = calculate_element_depth(v["expr"])

        max_branch_depth =
          v["branches"]
          |> Enum.map(fn branch -> calculate_element_depth(branch["result"]) end)
          |> Enum.max(default: 0)

        1 + max(expr_depth, max_branch_depth)

      _ ->
        1
    end
  end

  defp calculate_element_depth(%{"g" => _} = gexpr), do: calculate_depth(gexpr)
  defp calculate_element_depth(_), do: 0

  defp typeof(value) do
    cond do
      is_binary(value) -> :string
      is_number(value) -> :number
      is_boolean(value) -> :boolean
      is_list(value) -> :list
      is_map(value) -> :map
      true -> :unknown
    end
  end

  defp build_validation_error(%{"g" => g_type} = expr) do
    case g_type do
      "lit" -> "Literal expression missing or invalid 'v' field"
      "ref" -> "Reference expression 'v' field must be a string"
      "vec" -> build_vector_error(expr)
      "app" -> build_application_error(expr)
      "lam" -> build_lambda_error(expr)
      "fix" -> "Fixpoint expression has invalid nested G-expression"
      "match" -> build_match_error(expr)
      unknown -> "Unknown G-expression type: '#{unknown}'"
    end
  end

  defp build_validation_error(%{} = expr) do
    if Map.has_key?(expr, "g") do
      "G-expression 'g' field is not a string"
    else
      "G-expression missing required 'g' field"
    end
  end

  defp build_validation_error(_) do
    "G-expression must be a JSON object with 'g' and 'v' fields"
  end

  defp build_vector_error(%{"v" => v}) when not is_list(v) do
    "Vector expression 'v' field must be a list"
  end

  defp build_vector_error(%{"v" => items}) do
    invalid_items =
      items
      |> Enum.with_index()
      |> Enum.filter(fn {item, _idx} ->
        case item do
          %{"g" => _} -> not is_valid_gexpression?(item)
          _ -> false
        end
      end)
      |> Enum.map(fn {_item, idx} -> "item #{idx}" end)

    case invalid_items do
      [] -> "Vector contains invalid G-expressions"
      items -> "Vector contains invalid G-expressions at: #{Enum.join(items, ", ")}"
    end
  end

  defp build_application_error(%{"v" => %{"fn" => fn_expr} = app_data}) do
    cond do
      not is_valid_gexpression?(fn_expr) ->
        "Application function is not a valid G-expression"

      Map.has_key?(app_data, "args") and not is_valid_gexpression?(app_data["args"]) ->
        "Application arguments are not a valid G-expression"

      true ->
        "Application expression structure is invalid"
    end
  end

  defp build_application_error(_) do
    "Application expression missing 'fn' field in 'v'"
  end

  defp build_lambda_error(%{"v" => %{"params" => params, "body" => body}}) do
    cond do
      not is_list(params) ->
        "Lambda parameters must be a list"

      not Enum.all?(params, &is_binary/1) ->
        "All lambda parameters must be strings"

      not is_valid_gexpression?(body) ->
        "Lambda body is not a valid G-expression"

      true ->
        "Lambda expression structure is invalid"
    end
  end

  defp build_lambda_error(_) do
    "Lambda expression missing 'params' or 'body' in 'v'"
  end

  defp build_match_error(%{"v" => %{"expr" => expr, "branches" => branches}}) do
    cond do
      not is_valid_gexpression?(expr) ->
        "Match expression is not a valid G-expression"

      not is_list(branches) ->
        "Match branches must be a list"

      true ->
        invalid_branches =
          branches
          |> Enum.with_index()
          |> Enum.filter(fn {branch, _idx} -> not valid_branch?(branch) end)
          |> Enum.map(fn {_branch, idx} -> "branch #{idx}" end)

        case invalid_branches do
          [] -> "Match expression structure is invalid"
          branches -> "Invalid branches at: #{Enum.join(branches, ", ")}"
        end
    end
  end

  defp build_match_error(_) do
    "Match expression missing 'expr' or 'branches' in 'v'"
  end

  defp generate_suggestions(gexpr, _reason) do
    suggestions = []

    # Basic structure suggestions
    suggestions =
      if not is_map(gexpr) do
        ["G-expression must be a JSON object" | suggestions]
      else
        suggestions
      end

    # Missing 'g' field
    suggestions =
      if is_map(gexpr) and not Map.has_key?(gexpr, "g") do
        [
          "Add a 'g' field specifying the expression type (lit, ref, vec, app, lam, fix, match)"
          | suggestions
        ]
      else
        suggestions
      end

    # Invalid 'g' field
    suggestions =
      if is_map(gexpr) and Map.has_key?(gexpr, "g") and not is_binary(gexpr["g"]) do
        ["The 'g' field must be a string" | suggestions]
      else
        suggestions
      end

    # Missing 'v' field
    suggestions =
      if is_map(gexpr) and not Map.has_key?(gexpr, "v") do
        ["Add a 'v' field containing the expression value" | suggestions]
      else
        suggestions
      end

    Enum.reverse(suggestions)
  end
end
