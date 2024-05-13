defmodule ParsingXML.Cart.Types.Number do
  @moduledoc """
  Convert to and from custom syntax for number with K/M/G modifiers
  """

  use Ecto.Type

  def type, do: :integer

  def cast(str) when is_binary(str) do
    case Ecto.Type.cast(type(), str) do
      {:ok, value} ->
        {:ok, value}

      :error ->
        case Regex.run(~r/([0-9]+)([kmg])/i, str) do
          nil ->
            :error

          [_string, number, unit] ->
            with {:ok, value} <- Ecto.Type.cast(type(), number) do
              parse(value, String.upcase(unit))
            end
        end
    end
  end

  def load(term), do: Ecto.Type.load(type(), term)

  def dump(integer) when is_integer(integer) do
    {number, unit} =
      case div(integer, 1_000) do
        result when result >= 1_000_000 -> {div(result, 1_000_000), "G"}
        result when result >= 1_000 -> {div(result, 1_000), "M"}
        result when result >= 1 -> {result, "K"}
        _result -> {integer, ""}
      end

    {:ok, Integer.to_string(number) <> unit}
  end

  defp parse(number, "K"), do: {:ok, number * 1_000}
  defp parse(number, "M"), do: {:ok, number * 1_000_000}
  defp parse(number, "G"), do: {:ok, number * 1_000_000_000}
  defp parse(_number, _unit), do: :error
end
