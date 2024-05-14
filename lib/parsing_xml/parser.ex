defmodule ParsingXML.Parser do
  @moduledoc "XML Parser"

  require Logger

  @type data :: binary()
  @type attributes :: [{String.t(), String.t()}]
  @type path :: [atom()]
  @type xpath :: String.t()
  @type state :: term()
  @type attribute :: String.t()
  @type value :: String.t()

  @type t :: module()
  @type parser :: %__MODULE__{}

  @enforce_keys [:module]
  defstruct module: nil, path: "", state: nil

  @callback start_document :: state()
  @callback end_document(state()) :: {:ok, term()} | {:error, term()}
  @callback handle_xpath_element(xpath(), attributes(), state()) ::
              {:ok, state} | :keep_state | {:error, term()} | {:cont, t()}
  @callback handle_xpath_data(xpath(), value(), state()) ::
              {:ok, state()} | :keep_state | {:error, term()} | {:cont, t()}

  defmacro __using__(options) do
    schema = options[:schema] && Macro.expand(options[:schema], __CALLER__)

    end_document = generate_end_document(schema)
    handle_xpath_element = generate_handle_xpath_element(schema)
    handle_xpath_data = generate_handle_xpath_data(schema)

    if options[:debug] do
      end_document |> Macro.to_string() |> Code.format_string!() |> IO.puts()
      handle_xpath_element |> Macro.to_string() |> Code.format_string!() |> IO.puts()
      handle_xpath_data |> Macro.to_string() |> Code.format_string!() |> IO.puts()
    end

    quote do
      @behaviour ParsingXML.Parser

      @impl ParsingXML.Parser
      def start_document, do: %{}

      @impl ParsingXML.Parser
      unquote(end_document)

      @impl ParsingXML.Parser
      unquote(handle_xpath_element)
      def handle_xpath_element(_xpath, _attributes, _state), do: :keep_state

      @impl ParsingXML.Parser
      unquote(handle_xpath_data)
      def handle_xpath_data(_path, _data, _state), do: :keep_state

      defoverridable ParsingXML.Parser

      @doc "Parse an XML document"
      @spec parse(ParsingXML.Parser.data()) ::
              {:ok, ParsingXML.Parser.state()} | {:error, term()}
      # credo:disable-for-next-line
      def parse(data), do: ParsingXML.Parser.parse(__MODULE__, data)

      @doc "Stream an XML document"
      @spec stream(ParsingXML.Parser.data()) ::
              {:ok, ParsingXML.Parser.state()} | {:error, term()}
      # credo:disable-for-next-line
      def stream(data), do: ParsingXML.Parser.stream(__MODULE__, data)
    end
  end

  @doc "Parse an XML document"
  @spec parse(t(), data()) :: {:ok, term()} | {:error, term()}
  def parse(module, data) do
    case Saxy.parse_string(data, __MODULE__, %__MODULE__{module: module}) do
      {:ok, {:error, _errors} = error} -> error
      return -> return
    end
  end

  @doc "Parse an XML document stream"
  @spec stream(t(), Enumerable.t()) :: {:ok, term()} | {:error, term()}
  def stream(module, stream) do
    case Saxy.parse_stream(stream, __MODULE__, %__MODULE__{module: module}) do
      {:ok, {:error, _errors} = error} -> error
      return -> return
    end
  end

  @behaviour Saxy.Handler

  @impl Saxy.Handler
  def handle_event(:start_document, _data, %__MODULE__{} = parser) do
    parser = %{parser | state: parser.module.start_document()}
    Logger.debug("start document", parser: inspect(parser))
    {:ok, parser}
  end

  def handle_event(:start_element, {element, attributes}, %__MODULE__{} = parser) do
    path = parser.path <> "/" <> get_name(element)
    Logger.debug("start element", element: element, attributes: attributes)

    case parser.module.handle_xpath_element(path, attributes, parser.state) do
      {:ok, state} ->
        parser = %{parser | path: path, state: state}
        Logger.debug("parsed element", parser: inspect(parser))
        {:ok, parser}

      {:cont, module} ->
        parser = %{parser | module: module}
        Logger.debug("switching parser", parser: inspect(parser))
        handle_event(:start_element, {element, attributes}, parser)

      :keep_state ->
        parser = %{parser | path: path}
        Logger.debug("ignoring start element", parser: inspect(parser))
        {:ok, parser}

      {:error, reason} = error ->
        parser = %{parser | path: path}
        Logger.error("start element error", parser: inspect(parser), error: reason)
        {:stop, error}
    end
  rescue
    exception ->
      Logger.error("parser crashed handling element",
        parser: inspect(parser),
        error: Exception.format(:error, exception, __STACKTRACE__)
      )

      {:stop, {:error, exception}}
  end

  def handle_event(:end_element, element, %__MODULE__{} = parser) do
    Logger.debug("end element", parser: inspect(parser))
    {:ok, %{parser | path: String.replace_trailing(parser.path, "/" <> get_name(element), "")}}
  end

  def handle_event(:characters, value, %__MODULE__{} = parser) do
    Logger.debug("characters", parser: inspect(parser), value: value)

    case parser.module.handle_xpath_data(parser.path, value, parser.state) do
      {:ok, state} ->
        parser = %{parser | state: state}
        Logger.debug("parsed element value", parser: inspect(parser))
        {:ok, parser}

      {:cont, module} ->
        parser = %{parser | module: module}
        Logger.debug("switching parser", parser: inspect(parser))
        handle_event(:characters, value, parser)

      :keep_state ->
        Logger.debug("ignoring element value", parser: inspect(parser))
        {:ok, parser}

      {:error, reason} = error ->
        Logger.error("invalid path", parser: inspect(parser), error: reason)
        {:stop, error}
    end
  rescue
    exception ->
      Logger.error("parser chrashed handling element data",
        parser: inspect(parser),
        error: Exception.format(:error, exception, __STACKTRACE__)
      )

      {:stop, {:error, exception}}
  end

  def handle_event(:end_document, _data, %__MODULE__{} = parser) do
    Logger.debug("end document", parser: inspect(parser))
    parser.module.end_document(parser.state)
  end

  defp get_name(element) do
    case String.split(element, ":", parts: 2) do
      [_namespace, name] ->
        name

      [name] ->
        name
    end
  end

  defp generate_handle_xpath_element(nil = _schema), do: []

  defp generate_handle_xpath_element(schema) do
    prefix =
      schema.__schema__(:prefix) ||
        raise "You must specify @schema_prefix on your embedded schema with the root element name"

    generate_handle_xpath_element(schema, ["/" <> to_string(prefix)], [], [])
  end

  defp generate_handle_xpath_element(schema, path, keys, functions) do
    Enum.reduce(schema.__schema__(:fields), functions, fn field, functions ->
      field_source = schema.__schema__(:field_source, field)

      field_name =
        if field_source != field do
          to_string(field_source)
        else
          Recase.to_pascal(to_string(field))
        end

      path = path ++ [field_name]
      keys = keys ++ [field]

      case schema.__schema__(:type, field) do
        {:parameterized, Ecto.Embedded, %Ecto.Embedded{cardinality: :one} = embed} ->
          functions = [
            quote do
              def handle_xpath_element(unquote(Enum.join(path, "/")), _attributes, state) do
                {:ok, put_in(state, unquote(keys), %{})}
              end
            end
            | functions
          ]

          generate_handle_xpath_element(embed.related, path, keys, functions)

        {:parameterized, Ecto.Embedded, %Ecto.Embedded{} = embed} ->
          functions = [
            quote do
              def handle_xpath_element(unquote(Enum.join(path, "/")), _attributes, state) do
                {
                  :ok,
                  update_in(state, unquote(keys), fn
                    nil -> [%{}]
                    values -> values ++ [%{}]
                  end)
                }
              end
            end
            | functions
          ]

          generate_handle_xpath_element(
            embed.related,
            path,
            keys ++ [quote(do: Access.at(-1))],
            functions
          )

        {:array, _type} ->
          functions

        _primitive ->
          functions
      end
    end)
  end

  defp generate_handle_xpath_data(nil = _schema), do: []

  defp generate_handle_xpath_data(schema) do
    prefix =
      schema.__schema__(:prefix) ||
        raise "You must specify @schema_prefix on your embedded schema with the root element name"

    generate_handle_xpath_data(schema, ["/" <> to_string(prefix)], [], [])
  end

  defp generate_handle_xpath_data(schema, path, keys, functions) do
    Enum.reduce(schema.__schema__(:fields), functions, fn field, functions ->
      field_source = schema.__schema__(:field_source, field)

      field_name =
        if field_source != field do
          to_string(field_source)
        else
          Recase.to_pascal(to_string(field))
        end

      path = path ++ [field_name]
      keys = keys ++ [field]

      case schema.__schema__(:type, field) do
        {:parameterized, Ecto.Embedded, %Ecto.Embedded{cardinality: :one} = embed} ->
          generate_handle_xpath_data(embed.related, path, keys, functions)

        {:parameterized, Ecto.Embedded, %Ecto.Embedded{} = embed} ->
          generate_handle_xpath_data(
            embed.related,
            path,
            keys ++ [quote(do: Access.at(-1))],
            functions
          )

        {:array, _type} ->
          [
            quote do
              def handle_xpath_data(unquote(Enum.join(path, "/")), value, state) do
                {
                  :ok,
                  update_in(state, unquote(keys), fn
                    nil -> [String.trim(value)]
                    values -> values ++ [String.trim(value)]
                  end)
                }
              end
            end
            | functions
          ]

        _primitive ->
          [
            quote do
              def handle_xpath_data(unquote(Enum.join(path, "/")), value, state) do
                # credo:disable-for-next-line
                {
                  :ok,
                  update_in(state, unquote(keys), fn
                    nil -> String.trim(value)
                    values -> values <> String.trim(value)
                  end)
                }
              end
            end
            | functions
          ]
      end
    end)
  end

  defp generate_end_document(nil = _schema) do
    quote do
      def end_document(state), do: {:ok, state}
    end
  end

  defp generate_end_document(schema) do
    quote do
      def end_document(state) do
        case unquote(schema).changeset(%unquote(schema){}, state)
             |> Ecto.Changeset.apply_action(:cast) do
          {:ok, schema} ->
            {:ok, schema}

          {:error, changeset} ->
            {:stop, {:error, changeset}}
        end
      end
    end
  end
end
