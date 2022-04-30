defmodule Srh.Http.RequestValidator do
  def validate_redis_body(%{"_json" => command_array}) when is_list(command_array),
    do: {:ok, command_array}

  def validate_redis_body(_),
    do:
      {:error,
       "Invalid command array. Expected a string array at root of the command and its arguments."}

  def validate_pipeline_redis_body(%{"_json" => array_of_command_arrays})
      when is_list(array_of_command_arrays) do
    do_validate_pipeline_redis_body(array_of_command_arrays, array_of_command_arrays)
  end

  # any amount of items left
  defp do_validate_pipeline_redis_body([first_item | rest], original) do
    case do_validate_pipeline_item(first_item) do
      :ok -> do_validate_pipeline_redis_body(rest, original)
      :error -> {:error, "Invalid command array. Expected an array of string arrays at root."}
    end
  end

  defp do_validate_pipeline_redis_body([], original), do: {:ok, original}

  defp do_validate_pipeline_item(item) when is_list(item), do: :ok

  defp do_validate_pipeline_item(_), do: :error

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
