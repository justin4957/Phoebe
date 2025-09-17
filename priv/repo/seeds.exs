# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Phoebe.Repo.insert!(%Phoebe.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Phoebe.Repository
alias Phoebe.Repository.{GExpression, Version}

# Sample G-Expressions based on the json_ge_lib examples

# 1. Simple literal expression
{:ok, literal_expr} = Repository.create_g_expression(%{
  name: "simple_number",
  title: "Simple Number Literal",
  description: "A basic literal expression representing the number 42",
  expression_data: %{
    "g" => "lit",
    "v" => 42
  },
  tags: ["literal", "number", "basic"]
})

Repository.create_version(literal_expr, %{
  version: "1.0.0",
  expression_data: %{
    "g" => "lit",
    "v" => 42
  }
})

# 2. Simple lambda function
{:ok, identity_expr} = Repository.create_g_expression(%{
  name: "identity",
  title: "Identity Function",
  description: "A simple lambda function that returns its input unchanged",
  expression_data: %{
    "g" => "lam",
    "v" => %{
      "params" => ["x"],
      "body" => %{"g" => "ref", "v" => "x"}
    }
  },
  tags: ["lambda", "identity", "function", "basic"]
})

Repository.create_version(identity_expr, %{
  version: "1.0.0",
  expression_data: identity_expr.expression_data
})

# 3. Boolean logic expression
{:ok, and_expr} = Repository.create_g_expression(%{
  name: "logical_and",
  title: "Logical AND",
  description: "A lambda function implementing logical AND operation",
  expression_data: %{
    "g" => "lam",
    "v" => %{
      "params" => ["x", "y"],
      "body" => %{
        "g" => "match",
        "v" => %{
          "expr" => %{"g" => "ref", "v" => "x"},
          "branches" => [
            %{
              "pattern" => %{"lit_pattern" => true},
              "result" => %{"g" => "ref", "v" => "y"}
            },
            %{
              "pattern" => "else_pattern",
              "result" => %{"g" => "lit", "v" => false}
            }
          ]
        }
      }
    }
  },
  tags: ["logic", "boolean", "and", "conditional"]
})

Repository.create_version(and_expr, %{
  version: "1.0.0",
  expression_data: and_expr.expression_data
})

IO.puts("Seeded database with sample G-Expressions")
