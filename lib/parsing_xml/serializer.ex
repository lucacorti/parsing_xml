defmodule ParsingXML.Serializer do
  @moduledoc "XML Serializer"

  import Saxy.XML

  def serialize(%module{} = schema) do
    root = module.__schema__(:prefix) |> to_string() |> Recase.to_pascal()

    {
      :ok,
      element(
        root,
        generate_attrs(%Ecto.Embedded{cardinality: :one, related: module}, schema),
        generate_elements(schema, [])
      )
      |> Saxy.encode!(version: "1.0", encoding: "UTF-8")
    }
  end

  defp generate_elements(%schema{} = struct, elements) do
    data = Map.from_struct(struct)

    Enum.reduce(schema.__schema__(:fields), elements, fn field, elements ->
      {type, _from, source} = parse_source(schema, field)

      case {type, schema.__schema__(:type, field)} do
        {:element, {:parameterized, Ecto.Embedded, %Ecto.Embedded{cardinality: :one} = embed}} ->
          elements ++
            [
              element(
                source,
                generate_attrs(embed, data[field]),
                generate_elements(data[field], [])
              )
            ]

        {:element, {:parameterized, Ecto.Embedded, %Ecto.Embedded{} = embed}} ->
          {new_elements, _index} =
            Enum.map_reduce(data[field], 0, fn item, index ->
              {
                element(
                  source,
                  generate_attrs(embed, item),
                  generate_elements(item, [])
                ),
                index + 1
              }
            end)

          elements ++ new_elements

        {:element, {:array, type}} ->
          Enum.reduce_while(data[field], elements, fn value, elements ->
            case Ecto.Type.dump(type, value) do
              {:ok, value} ->
                {
                  :cont,
                  elements ++ [element(source, [], characters(value))]
                }

              :error ->
                {:halt, {:error, value}}
            end
          end)

        {:element, type} ->
          case Ecto.Type.dump(type, data[field]) do
            {:ok, value} ->
              elements ++ [element(source, [], characters(value))]

            :error ->
              {:error, data[field]}
          end

        {:attr, _type} ->
          elements
      end
    end)
  end

  defp generate_attrs(%Ecto.Embedded{} = embed, struct) do
    data = Map.from_struct(struct)

    Enum.reduce(embed.related.__schema__(:fields), [], fn field, attrs ->
      case parse_source(embed.related, field) do
        {:attr, :parent, name} ->
          [{name, data[field]} | attrs]

        _ ->
          attrs
      end
    end)
  end

  defp parse_source(schema, field) do
    field_source = schema.__schema__(:field_source, field)

    if field_source != field do
      source =
        to_string(field_source)
        |> String.split(":", parts: 3, trim: true)

      case source do
        ["attr", "parent", attr] ->
          {:attr, :parent, attr}

        [element] ->
          {:element, nil, element}
      end
    else
      {:element, nil, Recase.to_pascal(to_string(field))}
    end
  end
end
