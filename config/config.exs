import Config

config :srh,
       mode: "file",
       file_path: "srh-config/tokens.json"

import_config "#{config_env()}.exs"