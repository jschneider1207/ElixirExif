defmodule ElixirExif do
  @moduledoc """
  Provides exif tag parsing for jpeg images.
  """

  @max_length 2*(65536+2)
  @soi 0xFFD8
  @eoi 0xFFD9
  @app1 0xFFE1
  @gps_ifd 0x8825
  @exif_ifd 0x8769
  @interop_ifd 0xA005
  @thumbnail_offset 0x0201
  @thumbnail_length 0x0202
  @little_endian 0x4949
  @big_endian 0x4D4D
  @byte 1
  @ascii 2
  @short 3
  @long 4
  @rational 5
  @undefined 7
  @slong 9
  @srational 10

  @type tags :: map
  @type tumbnail :: binary

  @doc """
  Opens a jpeg image and parses out the exif tags and thumbnail data, if it exists.
  """
  @spec parse_file(String.t) ::
    {:ok, tags, tumbnail | nil} |
    {:error, reason :: term}
  def parse_file(path) do
    File.open!(path, [:read], &(IO.binread(&1, @max_length)))
    |> parse_binary
  end

  @doc """
  Parses out the exif tags and thumbnail data (if it exists) from a jpeg image.
  """
  @spec parse_file(binary) ::
    {:ok, tags, tumbnail | nil} |
    {:error, reason :: term}
  def parse_binary(<<@soi :: 16, rest :: binary>>) do
    rest
    |> find_app1
    |> parse_app1
  end
  def parse_binary(_), do: {:error, "Not a valid jpeg binary."}

  defp find_app1(<<@app1 :: 16, _length :: 16, "Exif" :: binary, 0 :: 16, rest :: binary>>), do: {:ok, rest}
  defp find_app1(<< 0xFF :: 8, _num :: 8, len :: 16, rest :: binary>>) do
    # Not app1, skip it
    <<_skip :: size(len)-unit(8), rest :: binary>> = rest
    find_app1(rest)
  end
  defp find_app1(_), do: {:error, "Cannot find app1 data."}

  defp parse_app1({:ok, app1}) do
    {endian, forty_two, header_offset} = parse_tiff_header(app1)
    read_unsigned = get_read_unsigned(endian)
    42 = read_unsigned.(forty_two) # double check
    offset = read_unsigned.(header_offset)

    fields = parse_first_ifds(app1, offset, read_unsigned)
    |> parse_idf_field(@exif_ifd, :exif, app1, read_unsigned)
    |> parse_idf_field(@gps_ifd, :gps, app1, read_unsigned)
    |> parse_idf_field(@interop_ifd, :interop, app1, read_unsigned)

    decoded = ElixirExif.Tag.decode_tags(fields, read_unsigned)
    thumbnail = extract_thumbnail(fields, app1, read_unsigned)

    {:ok, decoded, thumbnail}
  end
  defp parse_app1(error), do: error

  defp parse_tiff_header(<<@little_endian :: 16, forty_two :: binary-size(2), offset :: binary-size(4), _rest :: binary>>), do: {:little, forty_two, offset}
  defp parse_tiff_header(<<@big_endian :: 16, forty_two :: binary-size(2), offset :: binary-size(4), _rest :: binary>>), do: {:big, forty_two, offset}

  defp get_read_unsigned(:little), do: &(:binary.decode_unsigned(&1, :little))
  defp get_read_unsigned(:big), do: &(:binary.decode_unsigned(&1, :big))

  defp parse_idf(name, start_of_tiff, offset, read_unsigned, acc) do
    <<_ :: binary-size(offset), field_count :: binary-size(2), _rest :: binary>> = start_of_tiff
    field_count = read_unsigned.(field_count)
    field_length = field_count * 12
    <<_ :: binary-size(offset), _ :: binary-size(2), fields :: binary-size(field_length), next_offset :: binary-size(4), _rest :: binary>> = start_of_tiff
    next_offset = read_unsigned.(next_offset)
    fields = parse_fields(name, field_count, fields, start_of_tiff, read_unsigned, acc)
    {fields, next_offset}
  end

  defp parse_fields(_name, 0, _fields, _start_of_tiff, _read_unsigned, acc), do: acc
  defp parse_fields(name, remaining, <<tag_id :: binary-size(2), type_id :: binary-size(2), component_count :: binary-size(4), value :: binary-size(4), rest :: binary>>, start_of_tiff, read_unsigned, acc) do
    tag_id = read_unsigned.(tag_id)
    type_id = read_unsigned.(type_id)
    component_count = read_unsigned.(component_count)
    field_byte_length = get_field_byte_length(type_id, component_count)
    fixed_value =
      if field_byte_length > 4 do
        value_offset = read_unsigned.(value)
        <<_ :: binary-size(value_offset), new_value :: binary-size(field_byte_length), _ :: binary>> = start_of_tiff
        new_value
      else
        value
      end
    parse_fields(name, remaining - 1, rest, start_of_tiff, read_unsigned,
      MapSet.put(acc, %{tag_id: tag_id,
                        idf: name,
                        type_id: type_id,
                        component_count: component_count,
                        value: fixed_value}))
  end

  defp find_field(fields, tag_id) do
    fields
    |> Enum.find(fn %{tag_id: ^tag_id} -> true
                    _ -> false end)
  end

  defp get_field_byte_length(@byte, component_count), do: component_count
  defp get_field_byte_length(@ascii, component_count), do: component_count
  defp get_field_byte_length(@short, component_count), do: 2*component_count
  defp get_field_byte_length(@long, component_count), do: 4*component_count
  defp get_field_byte_length(@rational, component_count), do: 8*component_count
  defp get_field_byte_length(@undefined, component_count), do: component_count
  defp get_field_byte_length(@slong, component_count), do: 4*component_count
  defp get_field_byte_length(@srational, component_count), do: 8*component_count

  defp parse_first_ifds(app1, offset, read_unsigned) do
    {fields, next_offset} = parse_idf(:tiff, app1, offset, read_unsigned, MapSet.new) # parse 0th IFD

    if next_offset == 0 do
      fields
    else
      {new_fields, _} = parse_idf(:tiff, app1, next_offset, read_unsigned, fields) # parse 1st IFD
      new_fields
    end
  end

  defp parse_idf_field(fields, id, type, app1, read_unsigned) do
    tag = find_field(fields, id)

    if tag == nil do
      fields
    else
      offset = read_unsigned.(tag.value)
      {new_fields, _} = parse_idf(type, app1, offset, read_unsigned, fields)
      new_fields
    end
  end

  defp extract_thumbnail(fields, app1, read_unsigned) do
    thumbnail_offset_tag = find_field(fields, @thumbnail_offset)
    thumbnail_length_tag = find_field(fields, @thumbnail_length)

    unless thumbnail_offset_tag == nil or thumbnail_length_tag == nil do
      thumbnail_offset = read_unsigned.(thumbnail_offset_tag.value)
      thumbnail_length = read_unsigned.(thumbnail_length_tag.value)
      <<_ :: binary-size(thumbnail_offset), thumbnail :: binary-size(thumbnail_length), _ :: binary>> = app1
      thumbnail
    else
      nil
    end
  end
end
