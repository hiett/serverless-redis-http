defmodule Srh.Redis.ConnectionOpts do
  # Both Srh.Redis.ClientWorker (commands) and Srh.Redis.PubSubWorker (pub/sub) connect
  # via Redix, and need to enable SSL the same way when given a rediss:// URL.
  def build(connection_string) when is_binary(connection_string) do
    enable_ssl = String.starts_with?(connection_string, "rediss://")

    socket_opts =
      case enable_ssl do
        true ->
          [
            customize_hostname_check: [
              match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
            ]
          ]

        false ->
          []
      end

    [ssl: enable_ssl, socket_opts: socket_opts]
  end
end
