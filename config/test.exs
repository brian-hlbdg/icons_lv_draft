import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :icons_lv_draft, IconsLvDraftWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "0kPBnWA3c4Z4bRq7F77grbrRR0N7ai7G1YB0/K8qqZygV/CqlRSB8yhUQbk3ID2j",
  server: false

# In test we don't send emails.
config :icons_lv_draft, IconsLvDraft.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true
