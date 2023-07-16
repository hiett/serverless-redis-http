defmodule Srh.Http.ResultEncoder do

  # Authentication errors don't get encoded, we need to skip over those
  def encode_response({:not_authorized, message}) do
    {:not_authorized, message}
  end

  # Errors don't get encoded, we need to skip over those
  def encode_response({:redis_error, error_result_map}) do
    {:redis_error, error_result_map}
  end

  # List-based responses, they will contain multiple entries
  # It's important to note that this is DIFFERENT from a list of values,
  # as it's a list of separate command responses. Each is a map that either
  # Contains a result or an error
  def encode_response({:ok, result_list}) when is_list(result_list) do
    # Each one of these entries needs to be encoded
    {:ok, encode_response_list(result_list, [])}
  end

  # Single item response
  def encode_response({:ok, %{result: result_value}}) do
    {:ok, %{result: encode_result_value(result_value)}}
  end

  ## RESULT LIST ENCODING ##

  defp encode_response_list([current | rest], encoded_responses) do
    encoded_current_entry = case current do
      %{result: value} ->
        %{result: encode_result_value(value)} # Encode the value
      %{error: error_message} ->
        %{error: error_message} # We don't encode errors
    end

    encode_response_list(rest, [encoded_current_entry | encoded_responses])
  end

  defp encode_response_list([], encoded_responses) do
    Enum.reverse(encoded_responses)
  end

  ## RESULT VALUE ENCODING ##

  # Numbers are ignored
  defp encode_result_value(value) when is_number(value), do: value

  # Null/nil is ignored
  defp encode_result_value(value) when is_nil(value), do: value

  # Strings / blobs (any binary data) is encoded to Base64
  defp encode_result_value(value) when is_binary(value), do: Base.encode64(value)

  defp encode_result_value(arr) when is_list(arr) do
    encode_result_value_list(arr, [])
  end

  ## RESULT VALUE LIST ENCODING ##

  # Arrays can have values that are encoded, or aren't, based on whats laid out above
  defp encode_result_value_list([current | rest], encoded_responses) do
    encoded_value = encode_result_value(current)
    encode_result_value_list(rest, [encoded_value | encoded_responses])
  end

  defp encode_result_value_list([], encoded_responses) do
    # There are no responses left, and since we add them backwards, we need to flip the list
    Enum.reverse(encoded_responses)
  end
end
