defmodule PhoebeWeb.ChangesetJSON do
  @doc """
  Renders changeset errors.
  """
  def error(%{changeset: changeset}) do
    # When encoded, the changeset returns its errors
    # as a JSON object. So we just pass it forward.
    %{errors: translate_errors(changeset)}
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
  end

  defp translate_error({msg, opts}) do
    # You can make use of gettext to translate error messages by
    # uncommenting the following line:
    #
    # Gettext.dgettext(PhoebeWeb.Gettext, "errors", msg, opts)
    #
    # To merge interpolations from the field name and the validation itself,
    # you can use the special `field` key within the error opts:
    #
    # %{validation: :required, field: "email"} -> "email is required"
    #
    # Because we have the error message as a string, we can also
    # interpolate directly:
    if count = opts[:count] do
      Gettext.dngettext(PhoebeWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(PhoebeWeb.Gettext, "errors", msg, opts)
    end
  end
end
