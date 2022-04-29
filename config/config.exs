import Config

config :srh,
       mode: "file",
       file_path: "srh-config/tokens.json",
       file_hard_reload: false

import_config "#{config_env()}.exs"