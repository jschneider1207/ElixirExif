defmodule ElixirExif.Tag do
  @max_signed_32_bit_int 2147483647

  def decode_tags(tags, read_unsigned) do
    Enum.map(tags, &(decode_tag(&1, read_unsigned)))
    |> Enum.into(%{})
  end

  def decode_tag(%{tag_id: tag_id, idf: idf, type_id: type_id, component_count: component_count, value: value}, read_unsigned) do
    name = get_tag_name(idf, tag_id)
    value = decode_value(type_id, component_count, read_unsigned, value)
    {name, value}
  end

  defp decode_value(1, component_count, read_unsigned, value), do: decode_numeric(value, component_count, 1, read_unsigned) # byte
  defp decode_value(2, component_count, _read_unsigned, value) do # acii
    length = component_count - 1
    <<string :: binary-size(length), _null :: binary>> = value
    string
  end
  defp decode_value(3, component_count, read_unsigned, value), do: decode_numeric(value, component_count, 2, read_unsigned) # short
  defp decode_value(4, component_count, read_unsigned, value), do: decode_numeric(value, component_count, 4, read_unsigned) # long
  defp decode_value(5, component_count, read_unsigned, value), do: decode_ratio(value, component_count, read_unsigned) # rational
  defp decode_value(7, component_count, read_unsigned, value), do: decode_numeric(value, component_count, 1, read_unsigned) # undefined
  defp decode_value(9, component_count, read_unsigned, value) do #slong
    decode_numeric(value, component_count, 4, read_unsigned)
    |>maybe_signed_int(:signed)
  end
  defp decode_value(10, _component_count, _read_unsigned, _value), do: nil#decode_ratio(value, component_count, read_unsigned, :signed) # srational

  defp decode_numeric(value, component_count, size, read_unsigned) do
    length = component_count * size
    <<data :: binary-size(length), _ :: binary>> = value
    if component_count == 1 do
      read_unsigned.(data)
    else
      read_unsigned_many(data, size, read_unsigned)
    end
  end

  defp read_unsigned_many(<<>>, _size, _read_unsigned), do: []
  defp read_unsigned_many(data, size, read_unsigned) do
    << number :: binary-size(size), rest :: binary >> = data
    [read_unsigned.(number) | read_unsigned_many(rest, size, read_unsigned)]
  end

  defp decode_ratio(value, component_count, read_unsigned, signed \\ :unsigned), do: do_decode_ratio(value, component_count, read_unsigned, signed)
  defp do_decode_ratio(_value, 0, _read_unsigned, _signed), do: []
  defp do_decode_ratio(value, component_count, read_unsigned, signed) do
    <<numerator :: binary-size(4), denominator :: binary-size(4), rest :: binary>> = value
    numerator = read_unsigned.(numerator) |> maybe_signed_int(signed)
    denominator = read_unsigned.(denominator) |> maybe_signed_int(signed)
    result = case {numerator, denominator} do
      {numerator, 1} -> numerator
      {1, denominator} -> "1/#{denominator}"
      {numerator, denominator} -> numerator/denominator
    end
    [result | do_decode_ratio(rest, component_count-1, read_unsigned, signed)]
  end

  defp maybe_signed_int(x, :signed) when x > @max_signed_32_bit_int, do: x - @max_signed_32_bit_int - 1
  defp maybe_signed_int(x, _), do: x  # +ve or unsigned

  # parsed from http://www.exiv2.org/tags.html
  defp get_tag_name(:tiff, 0x000b), do: :processing_software
  defp get_tag_name(:tiff, 0x00fe), do: :new_subfile_type
  defp get_tag_name(:tiff, 0x00ff), do: :subfile_type
  defp get_tag_name(:tiff, 0x0100), do: :image_width
  defp get_tag_name(:tiff, 0x0101), do: :image_length
  defp get_tag_name(:tiff, 0x0102), do: :bits_per_sample
  defp get_tag_name(:tiff, 0x0103), do: :compression
  defp get_tag_name(:tiff, 0x0106), do: :photometric_interpretation
  defp get_tag_name(:tiff, 0x0107), do: :thresholding
  defp get_tag_name(:tiff, 0x0108), do: :cell_width
  defp get_tag_name(:tiff, 0x0109), do: :cell_length
  defp get_tag_name(:tiff, 0x010a), do: :fill_order
  defp get_tag_name(:tiff, 0x010d), do: :document_name
  defp get_tag_name(:tiff, 0x010e), do: :image_description
  defp get_tag_name(:tiff, 0x010f), do: :make
  defp get_tag_name(:tiff, 0x0110), do: :model
  defp get_tag_name(:tiff, 0x0111), do: :strip_offsets
  defp get_tag_name(:tiff, 0x0112), do: :orientation
  defp get_tag_name(:tiff, 0x0115), do: :samples_per_pixel
  defp get_tag_name(:tiff, 0x0116), do: :rows_per_strip
  defp get_tag_name(:tiff, 0x0117), do: :strip_byte_counts
  defp get_tag_name(:tiff, 0x011a), do: :x_resolution
  defp get_tag_name(:tiff, 0x011b), do: :y_resolution
  defp get_tag_name(:tiff, 0x011c), do: :planar_configuration
  defp get_tag_name(:tiff, 0x0122), do: :gray_response_unit
  defp get_tag_name(:tiff, 0x0123), do: :gray_response_curve
  defp get_tag_name(:tiff, 0x0124), do: :t4_options
  defp get_tag_name(:tiff, 0x0125), do: :t6_options
  defp get_tag_name(:tiff, 0x0128), do: :resolution_unit
  defp get_tag_name(:tiff, 0x0129), do: :page_number
  defp get_tag_name(:tiff, 0x012d), do: :transfer_function
  defp get_tag_name(:tiff, 0x0131), do: :software
  defp get_tag_name(:tiff, 0x0132), do: :date_time
  defp get_tag_name(:tiff, 0x013b), do: :artist
  defp get_tag_name(:tiff, 0x013c), do: :host_computer
  defp get_tag_name(:tiff, 0x013d), do: :predictor
  defp get_tag_name(:tiff, 0x013e), do: :white_point
  defp get_tag_name(:tiff, 0x013f), do: :primary_chromaticities
  defp get_tag_name(:tiff, 0x0140), do: :color_map
  defp get_tag_name(:tiff, 0x0141), do: :halftone_hints
  defp get_tag_name(:tiff, 0x0142), do: :tile_width
  defp get_tag_name(:tiff, 0x0143), do: :tile_length
  defp get_tag_name(:tiff, 0x0144), do: :tile_offsets
  defp get_tag_name(:tiff, 0x0145), do: :tile_byte_counts
  defp get_tag_name(:tiff, 0x014a), do: :sub_ifds
  defp get_tag_name(:tiff, 0x014c), do: :ink_set
  defp get_tag_name(:tiff, 0x014d), do: :ink_names
  defp get_tag_name(:tiff, 0x014e), do: :number_of_inks
  defp get_tag_name(:tiff, 0x0150), do: :dot_range
  defp get_tag_name(:tiff, 0x0151), do: :target_printer
  defp get_tag_name(:tiff, 0x0152), do: :extra_samples
  defp get_tag_name(:tiff, 0x0153), do: :sample_format
  defp get_tag_name(:tiff, 0x0154), do: :s_min_sample_value
  defp get_tag_name(:tiff, 0x0155), do: :s_max_sample_value
  defp get_tag_name(:tiff, 0x0156), do: :transfer_range
  defp get_tag_name(:tiff, 0x0157), do: :clip_path
  defp get_tag_name(:tiff, 0x0158), do: :x_clip_path_units
  defp get_tag_name(:tiff, 0x0159), do: :y_clip_path_units
  defp get_tag_name(:tiff, 0x015a), do: :indexed
  defp get_tag_name(:tiff, 0x015b), do: :jpeg_tables
  defp get_tag_name(:tiff, 0x015f), do: :o_p_i_proxy
  defp get_tag_name(:tiff, 0x0200), do: :jpeg_proc
  defp get_tag_name(:tiff, 0x0201), do: :jpeg_interchange_format
  defp get_tag_name(:tiff, 0x0202), do: :jpeg_interchange_format_length
  defp get_tag_name(:tiff, 0x0203), do: :jpeg_restart_interval
  defp get_tag_name(:tiff, 0x0205), do: :jpeg_lossless_predictors
  defp get_tag_name(:tiff, 0x0206), do: :jpeg_point_transforms
  defp get_tag_name(:tiff, 0x0207), do: :jpeg_q_tables
  defp get_tag_name(:tiff, 0x0208), do: :jpeg_dc_tables
  defp get_tag_name(:tiff, 0x0209), do: :jpeg_ac_tables
  defp get_tag_name(:tiff, 0x0211), do: :y_cb_cr_coefficients
  defp get_tag_name(:tiff, 0x0212), do: :y_cb_cr_sub_sampling
  defp get_tag_name(:tiff, 0x0213), do: :y_cb_cr_positioning
  defp get_tag_name(:tiff, 0x0214), do: :reference_black_white
  defp get_tag_name(:tiff, 0x02bc), do: :xml_packet
  defp get_tag_name(:tiff, 0x4746), do: :rating
  defp get_tag_name(:tiff, 0x4749), do: :rating_percent
  defp get_tag_name(:tiff, 0x800d), do: :image_id
  defp get_tag_name(:tiff, 0x828d), do: :cfa_repeat_pattern_dim
  defp get_tag_name(:tiff, 0x828e), do: :cfa_pattern
  defp get_tag_name(:tiff, 0x828f), do: :battery_level
  defp get_tag_name(:tiff, 0x8298), do: :copyright
  defp get_tag_name(:tiff, 0x829a), do: :exposure_time
  defp get_tag_name(:tiff, 0x829d), do: :f_number
  defp get_tag_name(:tiff, 0x83bb), do: :iptcnaa
  defp get_tag_name(:tiff, 0x8649), do: :image_resources
  defp get_tag_name(:tiff, 0x8769), do: :exif_tag
  defp get_tag_name(:tiff, 0x8773), do: :inter_color_profile
  defp get_tag_name(:tiff, 0x8822), do: :exposure_program
  defp get_tag_name(:tiff, 0x8824), do: :spectral_sensitivity
  defp get_tag_name(:tiff, 0x8825), do: :gps_tag
  defp get_tag_name(:tiff, 0x8827), do: :iso_speed_ratings
  defp get_tag_name(:tiff, 0x8828), do: :oecf
  defp get_tag_name(:tiff, 0x8829), do: :interlace
  defp get_tag_name(:tiff, 0x882a), do: :time_zone_offset
  defp get_tag_name(:tiff, 0x882b), do: :self_timer_mode
  defp get_tag_name(:tiff, 0x9003), do: :date_time_original
  defp get_tag_name(:tiff, 0x9102), do: :compressed_bits_per_pixel
  defp get_tag_name(:tiff, 0x9201), do: :shutter_speed_value
  defp get_tag_name(:tiff, 0x9202), do: :aperture_value
  defp get_tag_name(:tiff, 0x9203), do: :brightness_value
  defp get_tag_name(:tiff, 0x9204), do: :exposure_bias_value
  defp get_tag_name(:tiff, 0x9205), do: :max_aperture_value
  defp get_tag_name(:tiff, 0x9206), do: :subject_distance
  defp get_tag_name(:tiff, 0x9207), do: :metering_mode
  defp get_tag_name(:tiff, 0x9208), do: :light_source
  defp get_tag_name(:tiff, 0x9209), do: :flash
  defp get_tag_name(:tiff, 0x920a), do: :focal_length
  defp get_tag_name(:tiff, 0x920b), do: :flash_energy
  defp get_tag_name(:tiff, 0x920c), do: :spatial_frequency_response
  defp get_tag_name(:tiff, 0x920d), do: :noise
  defp get_tag_name(:tiff, 0x920e), do: :focal_plane_x_resolution
  defp get_tag_name(:tiff, 0x920f), do: :focal_plane_y_resolution
  defp get_tag_name(:tiff, 0x9210), do: :focal_plane_resolution_unit
  defp get_tag_name(:tiff, 0x9211), do: :image_number
  defp get_tag_name(:tiff, 0x9212), do: :security_classification
  defp get_tag_name(:tiff, 0x9213), do: :image_history
  defp get_tag_name(:tiff, 0x9214), do: :subject_location
  defp get_tag_name(:tiff, 0x9215), do: :exposure_index
  defp get_tag_name(:tiff, 0x9216), do: :tiff_ep_standard_id
  defp get_tag_name(:tiff, 0x9217), do: :sensing_method
  defp get_tag_name(:tiff, 0x9c9b), do: :xp_title
  defp get_tag_name(:tiff, 0x9c9c), do: :xp_comment
  defp get_tag_name(:tiff, 0x9c9d), do: :xp_author
  defp get_tag_name(:tiff, 0x9c9e), do: :xp_keywords
  defp get_tag_name(:tiff, 0x9c9f), do: :xp_subject
  defp get_tag_name(:tiff, 0xc4a5), do: :print_image_matching
  defp get_tag_name(:tiff, 0xc612), do: :dng_version
  defp get_tag_name(:tiff, 0xc613), do: :dng_backward_version
  defp get_tag_name(:tiff, 0xc614), do: :unique_camera_model
  defp get_tag_name(:tiff, 0xc615), do: :localized_camera_model
  defp get_tag_name(:tiff, 0xc616), do: :cfa_plane_color
  defp get_tag_name(:tiff, 0xc617), do: :cfa_layout
  defp get_tag_name(:tiff, 0xc618), do: :linearization_table
  defp get_tag_name(:tiff, 0xc619), do: :black_level_repeat_dim
  defp get_tag_name(:tiff, 0xc61a), do: :black_level
  defp get_tag_name(:tiff, 0xc61b), do: :black_level_delta_h
  defp get_tag_name(:tiff, 0xc61c), do: :black_level_delta_v
  defp get_tag_name(:tiff, 0xc61d), do: :white_level
  defp get_tag_name(:tiff, 0xc61e), do: :default_scale
  defp get_tag_name(:tiff, 0xc61f), do: :default_crop_origin
  defp get_tag_name(:tiff, 0xc620), do: :default_crop_size
  defp get_tag_name(:tiff, 0xc621), do: :color_matrix1
  defp get_tag_name(:tiff, 0xc622), do: :color_matrix2
  defp get_tag_name(:tiff, 0xc623), do: :camera_calibration1
  defp get_tag_name(:tiff, 0xc624), do: :camera_calibration2
  defp get_tag_name(:tiff, 0xc625), do: :reduction_matrix1
  defp get_tag_name(:tiff, 0xc626), do: :reduction_matrix2
  defp get_tag_name(:tiff, 0xc627), do: :analog_balance
  defp get_tag_name(:tiff, 0xc628), do: :as_shot_neutral
  defp get_tag_name(:tiff, 0xc629), do: :as_shot_white_x_y
  defp get_tag_name(:tiff, 0xc62a), do: :baseline_exposure
  defp get_tag_name(:tiff, 0xc62b), do: :baseline_noise
  defp get_tag_name(:tiff, 0xc62c), do: :baseline_sharpness
  defp get_tag_name(:tiff, 0xc62d), do: :bayer_green_split
  defp get_tag_name(:tiff, 0xc62e), do: :linear_response_limit
  defp get_tag_name(:tiff, 0xc62f), do: :camera_serial_number
  defp get_tag_name(:tiff, 0xc630), do: :lens_info
  defp get_tag_name(:tiff, 0xc631), do: :chroma_blur_radius
  defp get_tag_name(:tiff, 0xc632), do: :anti_alias_strength
  defp get_tag_name(:tiff, 0xc633), do: :shadow_scale
  defp get_tag_name(:tiff, 0xc634), do: :dng_private_data
  defp get_tag_name(:tiff, 0xc635), do: :maker_note_safety
  defp get_tag_name(:tiff, 0xc65a), do: :calibration_illuminant1
  defp get_tag_name(:tiff, 0xc65b), do: :calibration_illuminant2
  defp get_tag_name(:tiff, 0xc65c), do: :best_quality_scale
  defp get_tag_name(:tiff, 0xc65d), do: :raw_data_unique_i_d
  defp get_tag_name(:tiff, 0xc68b), do: :original_raw_file_name
  defp get_tag_name(:tiff, 0xc68c), do: :original_raw_file_data
  defp get_tag_name(:tiff, 0xc68d), do: :active_area
  defp get_tag_name(:tiff, 0xc68e), do: :masked_areas
  defp get_tag_name(:tiff, 0xc68f), do: :as_shot_icc_profile
  defp get_tag_name(:tiff, 0xc690), do: :as_shot_pre_profile_matrix
  defp get_tag_name(:tiff, 0xc691), do: :current_icc_profile
  defp get_tag_name(:tiff, 0xc692), do: :current_pre_profile_matrix
  defp get_tag_name(:tiff, 0xc6bf), do: :colorimetric_reference
  defp get_tag_name(:tiff, 0xc6f3), do: :camera_calibration_signature
  defp get_tag_name(:tiff, 0xc6f4), do: :profile_calibration_signature
  defp get_tag_name(:tiff, 0xc6f6), do: :as_shot_profile_name
  defp get_tag_name(:tiff, 0xc6f7), do: :noise_reduction_applied
  defp get_tag_name(:tiff, 0xc6f8), do: :profile_name
  defp get_tag_name(:tiff, 0xc6f9), do: :profile_hue_sat_map_dims
  defp get_tag_name(:tiff, 0xc6fa), do: :profile_hue_sat_map_data1
  defp get_tag_name(:tiff, 0xc6fb), do: :profile_hue_sat_map_data2
  defp get_tag_name(:tiff, 0xc6fc), do: :profile_tone_curve
  defp get_tag_name(:tiff, 0xc6fd), do: :profile_embed_policy
  defp get_tag_name(:tiff, 0xc6fe), do: :profile_copyright
  defp get_tag_name(:tiff, 0xc714), do: :forward_matrix1
  defp get_tag_name(:tiff, 0xc715), do: :forward_matrix2
  defp get_tag_name(:tiff, 0xc716), do: :preview_application_name
  defp get_tag_name(:tiff, 0xc717), do: :preview_application_version
  defp get_tag_name(:tiff, 0xc718), do: :preview_settings_name
  defp get_tag_name(:tiff, 0xc719), do: :preview_settings_digest
  defp get_tag_name(:tiff, 0xc71a), do: :preview_color_space
  defp get_tag_name(:tiff, 0xc71b), do: :preview_date_time
  defp get_tag_name(:tiff, 0xc71c), do: :raw_image_digest
  defp get_tag_name(:tiff, 0xc71d), do: :original_raw_file_digest
  defp get_tag_name(:tiff, 0xc71e), do: :sub_tile_block_size
  defp get_tag_name(:tiff, 0xc71f), do: :row_interleave_factor
  defp get_tag_name(:tiff, 0xc725), do: :profile_look_table_dims
  defp get_tag_name(:tiff, 0xc726), do: :profile_look_table_data
  defp get_tag_name(:tiff, 0xc740), do: :opcode_list1
  defp get_tag_name(:tiff, 0xc741), do: :opcode_list2
  defp get_tag_name(:tiff, 0xc74e), do: :opcode_list3
  defp get_tag_name(:tiff, 0xc761), do: :noise_profile
  defp get_tag_name(:exif, 0x829a), do: :exposure_time
  defp get_tag_name(:exif, 0x829d), do: :f_number
  defp get_tag_name(:exif, 0x8822), do: :exposure_program
  defp get_tag_name(:exif, 0x8824), do: :spectral_sensitivity
  defp get_tag_name(:exif, 0x8827), do: :iso_speed_ratings
  defp get_tag_name(:exif, 0x8828), do: :o_e_c_f
  defp get_tag_name(:exif, 0x8830), do: :sensitivity_type
  defp get_tag_name(:exif, 0x8831), do: :standard_output_sensitivity
  defp get_tag_name(:exif, 0x8832), do: :recommended_exposure_index
  defp get_tag_name(:exif, 0x8833), do: :iso_speed
  defp get_tag_name(:exif, 0x8834), do: :iso_speed_latitudeyyy
  defp get_tag_name(:exif, 0x8835), do: :iso_speed_latitudezzz
  defp get_tag_name(:exif, 0x9000), do: :exif_version
  defp get_tag_name(:exif, 0x9003), do: :date_time_original
  defp get_tag_name(:exif, 0x9004), do: :date_time_digitized
  defp get_tag_name(:exif, 0x9101), do: :components_configuration
  defp get_tag_name(:exif, 0x9102), do: :compressed_bits_per_pixel
  defp get_tag_name(:exif, 0x9201), do: :shutter_speed_value
  defp get_tag_name(:exif, 0x9202), do: :aperture_value
  defp get_tag_name(:exif, 0x9203), do: :brightness_value
  defp get_tag_name(:exif, 0x9204), do: :exposure_bias_value
  defp get_tag_name(:exif, 0x9205), do: :max_aperture_value
  defp get_tag_name(:exif, 0x9206), do: :subject_distance
  defp get_tag_name(:exif, 0x9207), do: :metering_mode
  defp get_tag_name(:exif, 0x9208), do: :light_source
  defp get_tag_name(:exif, 0x9209), do: :flash
  defp get_tag_name(:exif, 0x920a), do: :focal_length
  defp get_tag_name(:exif, 0x9214), do: :subject_area
  defp get_tag_name(:exif, 0x927c), do: :maker_note
  defp get_tag_name(:exif, 0x9286), do: :user_comment
  defp get_tag_name(:exif, 0x9290), do: :sub_sec_time
  defp get_tag_name(:exif, 0x9291), do: :sub_sec_time_original
  defp get_tag_name(:exif, 0x9292), do: :sub_sec_time_digitized
  defp get_tag_name(:exif, 0xa000), do: :flashpix_version
  defp get_tag_name(:exif, 0xa001), do: :color_space
  defp get_tag_name(:exif, 0xa002), do: :pixel_x_dimension
  defp get_tag_name(:exif, 0xa003), do: :pixel_y_dimension
  defp get_tag_name(:exif, 0xa004), do: :related_sound_file
  defp get_tag_name(:exif, 0xa005), do: :interoperability_tag
  defp get_tag_name(:exif, 0xa20b), do: :flash_energy
  defp get_tag_name(:exif, 0xa20c), do: :spatial_frequency_response
  defp get_tag_name(:exif, 0xa20e), do: :focal_plane_x_resolution
  defp get_tag_name(:exif, 0xa20f), do: :focal_plane_y_resolution
  defp get_tag_name(:exif, 0xa210), do: :focal_plane_resolution_unit
  defp get_tag_name(:exif, 0xa214), do: :subject_location
  defp get_tag_name(:exif, 0xa215), do: :exposure_index
  defp get_tag_name(:exif, 0xa217), do: :sensing_method
  defp get_tag_name(:exif, 0xa300), do: :file_source
  defp get_tag_name(:exif, 0xa301), do: :scene_type
  defp get_tag_name(:exif, 0xa302), do: :cfa_pattern
  defp get_tag_name(:exif, 0xa401), do: :custom_rendered
  defp get_tag_name(:exif, 0xa402), do: :exposure_mode
  defp get_tag_name(:exif, 0xa403), do: :white_balance
  defp get_tag_name(:exif, 0xa404), do: :digital_zoom_ratio
  defp get_tag_name(:exif, 0xa405), do: :focal_length_in35mm_film
  defp get_tag_name(:exif, 0xa406), do: :scene_capture_type
  defp get_tag_name(:exif, 0xa407), do: :gain_control
  defp get_tag_name(:exif, 0xa408), do: :contrast
  defp get_tag_name(:exif, 0xa409), do: :saturation
  defp get_tag_name(:exif, 0xa40a), do: :sharpness
  defp get_tag_name(:exif, 0xa40b), do: :device_setting_description
  defp get_tag_name(:exif, 0xa40c), do: :subject_distance_range
  defp get_tag_name(:exif, 0xa420), do: :image_unique_i_d
  defp get_tag_name(:exif, 0xa430), do: :camera_owner_name
  defp get_tag_name(:exif, 0xa431), do: :body_serial_number
  defp get_tag_name(:exif, 0xa432), do: :lens_specification
  defp get_tag_name(:exif, 0xa433), do: :lens_make
  defp get_tag_name(:exif, 0xa434), do: :lens_model
  defp get_tag_name(:exif, 0xa435), do: :lens_serial_number
  defp get_tag_name(:interop, 0x0001), do: :interoperability_index
  defp get_tag_name(:interop, 0x0002), do: :interoperability_version
  defp get_tag_name(:interop, 0x1000), do: :related_image_file_format
  defp get_tag_name(:interop, 0x1001), do: :related_image_width
  defp get_tag_name(:interop, 0x1002), do: :related_image_length
  defp get_tag_name(:gps, 0x0000), do: :gps_version_i_d
  defp get_tag_name(:gps, 0x0001), do: :gps_latitude_ref
  defp get_tag_name(:gps, 0x0002), do: :gps_latitude
  defp get_tag_name(:gps, 0x0003), do: :gps_longitude_ref
  defp get_tag_name(:gps, 0x0004), do: :gps_longitude
  defp get_tag_name(:gps, 0x0005), do: :gps_altitude_ref
  defp get_tag_name(:gps, 0x0006), do: :gps_altitude
  defp get_tag_name(:gps, 0x0007), do: :gps_time_stamp
  defp get_tag_name(:gps, 0x0008), do: :gps_satellites
  defp get_tag_name(:gps, 0x0009), do: :gps_status
  defp get_tag_name(:gps, 0x000a), do: :gps_measure_mode
  defp get_tag_name(:gps, 0x000b), do: :gps_d_o_p
  defp get_tag_name(:gps, 0x000c), do: :gps_speed_ref
  defp get_tag_name(:gps, 0x000d), do: :gps_speed
  defp get_tag_name(:gps, 0x000e), do: :gps_track_ref
  defp get_tag_name(:gps, 0x000f), do: :gps_track
  defp get_tag_name(:gps, 0x0010), do: :gps_img_direction_ref
  defp get_tag_name(:gps, 0x0011), do: :gps_img_direction
  defp get_tag_name(:gps, 0x0012), do: :gps_map_datum
  defp get_tag_name(:gps, 0x0013), do: :gps_dest_latitude_ref
  defp get_tag_name(:gps, 0x0014), do: :gps_dest_latitude
  defp get_tag_name(:gps, 0x0015), do: :gps_dest_longitude_ref
  defp get_tag_name(:gps, 0x0016), do: :gps_dest_longitude
  defp get_tag_name(:gps, 0x0017), do: :gps_dest_bearing_ref
  defp get_tag_name(:gps, 0x0018), do: :gps_dest_bearing
  defp get_tag_name(:gps, 0x0019), do: :gps_dest_distance_ref
  defp get_tag_name(:gps, 0x001a), do: :gps_dest_distance
  defp get_tag_name(:gps, 0x001b), do: :gps_processing_method
  defp get_tag_name(:gps, 0x001c), do: :gps_area_information
  defp get_tag_name(:gps, 0x001d), do: :gps_date_stamp
  defp get_tag_name(:gps, 0x001e), do: :gps_differential
  defp get_tag_name(ifd, tag), do: String.to_atom("#{ifd}_#{tag}")
end
