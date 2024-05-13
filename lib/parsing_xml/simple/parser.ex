defmodule ParsingXML.Simple.Parser do
  @moduledoc false

  use ParsingXML.Parser

  @impl ParsingXML.Parser
  def start_document, do: %{}

  @impl ParsingXML.Parser
  def handle_xpath_data("/Simple/CreatedAt", value, state) do
    with {:ok, created_at, _offset} <- DateTime.from_iso8601(value) do
      {:ok, Map.put(state, :created_at, created_at)}
    end
  end

  @impl ParsingXML.Parser
  def handle_xpath_data("/Simple/Title", value, state) do
    {:ok, Map.put(state, :title, value)}
  end

  @impl ParsingXML.Parser
  def handle_xpath_data("/Simple/Description", value, state) do
    {:ok, Map.put(state, :description, value)}
  end

  @impl ParsingXML.Parser
  def handle_xpath_data(_xpath, _value, _state), do: :keep_state

  # alias ParsingXML.Simple

  # @impl ParsingXML.Parser
  # def start_document, do: %Simple{}

  # @impl ParsingXML.Parser
  # def handle_xpath_data("/Simple/CreatedAt", value, %Simple{} = state) do
  #   with {:ok, created_at, _offset} <- DateTime.from_iso8601(value) do
  #     {:ok, %{state | created_at: created_at}}
  #   end
  # end

  # @impl ParsingXML.Parser
  # def handle_xpath_data("/Simple/Title", value, %Simple{} = state) do
  #   {:ok, %{state | title: value}}
  # end

  # @impl ParsingXML.Parser
  # def handle_xpath_data("/Simple/Description", value, %Simple{} = state) do
  #   {:ok, %{state | description: value}}
  # end

  # @impl ParsingXML.Parser
  # def handle_xpath_data(_xpath, _value, _state), do: :keep_state
end
