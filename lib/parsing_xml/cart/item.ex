defmodule ParsingXML.Cart.Item do
  @moduledoc false
  use Ecto.Schema

  alias ParsingXML.Cart.Types.Number

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :description
    field :purchased_at, :utc_datetime_usec
    field :quantity, Number
  end

  def changeset(schema, attrs) do
    cast(schema, attrs, [:description, :purchased_at, :quantity])
  end
end
