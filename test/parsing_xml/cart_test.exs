defmodule ParsingXML.CartTest do
  use ExUnit.Case, async: true

  alias ParsingXML.Cart
  alias ParsingXML.Cart.Parser

  test "parse serialize file" do
    assert {:ok, %Cart{} = struct1} =
             "test/parsing_xml/cart.xml"
             |> File.read!()
             |> Parser.parse()

    assert {:ok, xml1} = ParsingXML.Serializer.serialize(struct1)
    assert {:ok, struct2} = Parser.parse(xml1)
    assert {:ok, xml2} = ParsingXML.Serializer.serialize(struct2)
    assert xml1 == xml2
  end

  test "parse serialize stream" do
    assert {:ok, %Cart{} = struct1} =
             "test/parsing_xml/cart.xml"
             |> File.stream!()
             |> Parser.stream()

    assert {:ok, xml1} = ParsingXML.Serializer.serialize(struct1)
    assert {:ok, struct2} = Parser.stream(Stream.concat([[xml1]]))
    assert {:ok, xml2} = ParsingXML.Serializer.serialize(struct2)
    assert xml1 == xml2
  end

  test "parse error" do
    assert {:error, %Ecto.Changeset{valid?: false}} =
             "test/parsing_xml/wrong_cart.xml"
             |> File.read!()
             |> Parser.parse()
  end
end
