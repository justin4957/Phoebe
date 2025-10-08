defmodule Mix.Tasks.Phoebe do
  @moduledoc """
  Mix task wrapper for the Phoebe CLI.

  This allows running `mix phoebe` commands from the project directory.

  ## Examples

      mix phoebe help
      mix phoebe list
      mix phoebe create lit 42
      mix phoebe repl
  """

  use Mix.Task

  @shortdoc "Run Phoebe CLI commands"

  def run(args) do
    # Ensure required applications are started for HTTP client
    Application.ensure_all_started(:crypto)
    Application.ensure_all_started(:ssl)
    Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:phoebe)

    Phoebe.CLI.main(args)
  end
end
