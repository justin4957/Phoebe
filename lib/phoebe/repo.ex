defmodule Phoebe.Repo do
  use Ecto.Repo,
    otp_app: :phoebe,
    adapter: Ecto.Adapters.Postgres
end
