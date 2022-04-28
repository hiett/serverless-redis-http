defmodule Srh.Http.RequestValidator do
  def validate_redis_body(%{"_json" => command_array}) when is_list(command_array), do: {:ok, command_array}

  def validate_redis_body(payload),
      do: {:error, "Invalid command array. Expected a string array at root of the command and its arguments."}

  def validate_bearer_header(header_value_array) when is_list(header_value_array) do
    do_validate_bearer_header(header_value_array)
  end

  # any amount of items left
  defp do_validate_bearer_header([first_item | rest]) do
    case first_item
         |> String.split(" ") do
      ["Bearer", token] ->
        {:ok, token}
      _ ->
        do_validate_bearer_header(rest)
    end
  end
  
  # no items left
  defp do_validate_bearer_header([]), do: {:error, :not_found}
end
