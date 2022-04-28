defmodule Srh.Auth.TokenResolver do
  def resolve(token) do
    {
      :ok,
      Jason.decode!(
        # This is done to replicate what will eventually be API endpoints, so they keys are not atoms
        Jason.encode!(
          %{
            srh_id: "1000",
            connection_string: "redis://localhost:6379",
            max_connections: 10
          }
        )
      )
    }
  end
end
