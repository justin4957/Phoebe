defmodule Phoebe.GExpression.Validator do
  @moduledoc """
  Validates JSON G-Expression structures based on the specification from json_ge_lib.
  """

  @valid_types ~w(lit ref app vec lam fix match)

  @doc """
  Validates a JSON G-Expression structure.
  """
  def validate(expression_data) when is_map(expression_data) do
    case expression_data do
      %{"g" => type, "v" => value} when type in @valid_types ->
        validate_by_type(type, value)
        |> case do
          {:ok, _} -> {:ok, expression_data}
          error -> error
        end
      %{"g" => type} when not is_nil(type) ->
        {:error, "Invalid g-expression type: '#{type}'. Valid types are: #{Enum.join(@valid_types, ", ")}"}
      _ ->
        {:error, "Invalid g-expression format: must have 'g' (type) and 'v' (value) keys"}
    end
  end

  def validate(_), do: {:error, "G-expression must be a JSON object"}

  # Validate literal values
  defp validate_by_type("lit", value) do
    case value do
      v when is_number(v) or is_binary(v) or is_boolean(v) or is_nil(v) ->
        {:ok, value}
      v when is_list(v) ->
        {:ok, value}  # Arrays are valid literals
      _ ->
        {:error, "Literal value must be a number, string, boolean, null, or array"}
    end
  end

  # Validate variable references
  defp validate_by_type("ref", value) when is_binary(value) do
    if String.match?(value, ~r/^[a-zA-Z_][a-zA-Z0-9_]*[?]?$/) do
      {:ok, value}
    else
      {:error, "Reference must be a valid identifier"}
    end
  end
  defp validate_by_type("ref", _), do: {:error, "Reference value must be a string"}

  # Validate function applications
  defp validate_by_type("app", %{"fn" => fn_expr, "args" => args}) do
    with {:ok, _} <- validate(fn_expr),
         {:ok, _} <- validate_args(args) do
      {:ok, %{"fn" => fn_expr, "args" => args}}
    end
  end
  defp validate_by_type("app", %{"fn" => fn_expr}) do
    case validate(fn_expr) do
      {:ok, _} -> {:ok, %{"fn" => fn_expr}}
      error -> error
    end
  end
  defp validate_by_type("app", _), do: {:error, "Application must have 'fn' field"}

  # Validate vectors/arrays
  defp validate_by_type("vec", value) when is_list(value) do
    validate_expression_list(value)
    |> case do
      {:ok, _} -> {:ok, value}
      error -> error
    end
  end
  defp validate_by_type("vec", _), do: {:error, "Vector value must be an array"}

  # Validate lambda functions
  defp validate_by_type("lam", %{"params" => params, "body" => body}) when is_list(params) do
    with {:ok, _} <- validate_param_list(params),
         {:ok, _} <- validate(body) do
      {:ok, %{"params" => params, "body" => body}}
    end
  end
  defp validate_by_type("lam", _), do: {:error, "Lambda must have 'params' (array) and 'body' fields"}

  # Validate fixed-point combinator
  defp validate_by_type("fix", value) do
    case validate(value) do
      {:ok, _} -> {:ok, value}
      error -> error
    end
  end

  # Validate pattern matching
  defp validate_by_type("match", %{"expr" => expr, "branches" => branches}) when is_list(branches) do
    with {:ok, _} <- validate(expr),
         {:ok, _} <- validate_branches(branches) do
      {:ok, %{"expr" => expr, "branches" => branches}}
    end
  end
  defp validate_by_type("match", _), do: {:error, "Match must have 'expr' and 'branches' fields"}

  # Helper functions

  defp validate_args(args) when is_map(args) do
    validate(args)
  end
  defp validate_args(args) when is_list(args) do
    validate_expression_list(args)
  end
  defp validate_args(_), do: {:error, "Arguments must be a g-expression or array"}

  defp validate_expression_list([]), do: {:ok, []}
  defp validate_expression_list([expr | rest]) do
    case validate(expr) do
      {:ok, _} -> validate_expression_list(rest)
      error -> error
    end
  end

  defp validate_param_list([]), do: {:ok, []}
  defp validate_param_list([param | rest]) when is_binary(param) do
    if String.match?(param, ~r/^[a-zA-Z_][a-zA-Z0-9_]*$/) do
      validate_param_list(rest)
    else
      {:error, "Parameter '#{param}' must be a valid identifier"}
    end
  end
  defp validate_param_list([param | _]) do
    {:error, "Parameter must be a string, got: #{inspect(param)}"}
  end

  defp validate_branches([]), do: {:ok, []}
  defp validate_branches([branch | rest]) do
    case validate_branch(branch) do
      {:ok, _} -> validate_branches(rest)
      error -> error
    end
  end

  defp validate_branch(%{"pattern" => pattern, "result" => result}) do
    with {:ok, _} <- validate_pattern(pattern),
         {:ok, _} <- validate(result) do
      {:ok, %{"pattern" => pattern, "result" => result}}
    end
  end
  defp validate_branch(_), do: {:error, "Branch must have 'pattern' and 'result' fields"}

  defp validate_pattern(%{"lit_pattern" => true}), do: {:ok, %{"lit_pattern" => true}}
  defp validate_pattern("else_pattern"), do: {:ok, "else_pattern"}
  defp validate_pattern(pattern) when is_map(pattern), do: {:ok, pattern}
  defp validate_pattern(_), do: {:error, "Invalid pattern format"}
end