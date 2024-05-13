defmodule ParsingXML.Cart do
  @moduledoc false
  use Ecto.Schema

  alias ParsingXML.Cart.Item

  import Ecto.Changeset

  @primary_key false
  @schema_prefix :Cart
  embedded_schema do
    field :title
    field :notes, {:array, :string}

    embeds_one :main, Item
    embeds_many :items, Item, source: :Item
  end

  def changeset(schema, attrs) do
    cast(schema, attrs, [:notes, :title])
    |> cast_embed(:main, required: true)
    |> cast_embed(:items, required: true)
  end
end
