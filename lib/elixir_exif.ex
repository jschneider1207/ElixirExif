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

  @doc """
  Opens a jpeg image and parses out the exif tags and thumbnail data, if it exists.
  """
  def parse_file(path) do
    File.open!(path, [:read], &(IO.binread(&1, @max_length)))
    |> parse_binary
  end

  @doc """
  Parses out the exif tags and thumbnail data (if it exists) from a jpeg image.
  """
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
    {endian, forty_two, offset} = parse_tiff_header(app1)
    read_unsigned = get_read_unsigned(endian)
    42 = read_unsigned.(forty_two) # double check
    offset = read_unsigned.(offset)
    {fields, next_offset} = parse_idf(:tiff, app1, offset, read_unsigned, MapSet.new) # parse 0th IFD
    unless next_offset == 0 do
      {fields, _} = parse_idf(:tiff, app1, next_offset, read_unsigned, fields) # parse 1st IFD
    end
    exif_tag = find_field(fields, @exif_ifd)
    unless exif_tag == nil do
      exif_offset = read_unsigned.(exif_tag.value)
      {fields, _} = parse_idf(:exif, app1, exif_offset, read_unsigned, fields) # parse EXIF IFD
    end
    gps_tag = find_field(fields, @gps_ifd)
    unless gps_tag == nil do
      gps_offset = read_unsigned.(gps_tag.value)
      {fields, _} = parse_idf(:gps, app1, gps_offset, read_unsigned, fields) # parse GPS IFD
    end
    interop_tag = find_field(fields, @interop_ifd)
    unless interop_tag == nil do
      interop_offset = read_unsigned.(interop_tag.value)
      {fields, _} = parse_idf(:interop, app1, interop_offset, read_unsigned, fields) # parse interop IFD
    end
    thumbnail_offset_tag = find_field(fields, @thumbnail_offset)
    thumbnail_length_tag = find_field(fields, @thumbnail_length)
    decoded = ElixirExif.Tag.decode_tags(fields, read_unsigned)
    unless thumbnail_offset_tag == nil or thumbnail_length_tag == nil do
      thumbnail_offset = read_unsigned.(thumbnail_offset_tag.value)
      thumbnail_length = read_unsigned.(thumbnail_length_tag.value)
      <<_ :: binary-size(thumbnail_offset), thumbnail :: binary-size(thumbnail_length), _ :: binary>> = app1
      {:ok, decoded, thumbnail}
    else
      {:ok, decoded, nil}
    end
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
    if field_byte_length > 4 do
      value_offset = read_unsigned.(value)
      <<_ :: binary-size(value_offset), value :: binary-size(field_byte_length), _ :: binary>> = start_of_tiff
    end
    parse_fields(name, remaining - 1, rest, start_of_tiff, read_unsigned, MapSet.put(acc, %{tag_id: tag_id, idf: name, type_id: type_id, component_count: component_count, value: value}))
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
end
