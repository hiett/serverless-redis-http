import Config

config :srh,
       mode: "file",
       file_path: "srh-config/tokens.json",
       port: 8080

import_config "#{config_env()}.exs"
