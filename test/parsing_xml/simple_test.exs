defmodule ParsingXML.SimpleTest do
  use ExUnit.Case, async: true

  alias ParsingXML.Simple.Parser

  test "parse simple" do
    assert {:ok,
            %{
              created_at: ~U[2024-01-01 00:00:00Z],
              title: "A document",
              description: "Some textual lorem ipsum"
            }} =
             "test/parsing_xml/simple.xml"
             |> File.read!()
             |> Parser.parse()
  end

  # test "parse simple errors" do
  #   assert {:ok,
  #           %{
  #             created_at: ~U[2024-01-01 00:00:00Z],
  #             title: "A document",
  #             description: "Some textual lorem ipsum"
  #           }} =
  #            "test/parsing_xml/simple_errors.xml"
  #            |> File.read!()
  #            |> Parser.parse()
  # end

  # test "parse simple issues" do
  #   assert {:ok,
  #           %{
  #             created_at: ~U[2024-01-01 00:00:00Z],
  #             title: "A document",
  #             description: "Some textual lorem ipsum"
  #           }} =
  #            "test/parsing_xml/simple_issues.xml"
  #            |> File.read!()
  #            |> Parser.parse()
  # end
end
