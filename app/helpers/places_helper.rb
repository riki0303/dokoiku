module PlacesHelper
  # 距離感の日本語ラベル（近場 / 日帰り / 遠出）。config/locales/ja.yml の place/distance を使う
  def distance_label(distance)
    Place.human_attribute_name("distance.#{distance}")
  end

  # 距離感の選択肢。[ラベル, 値] の配列を返す
  def distance_options
    Place.distances.keys.map { |key| [ distance_label(key), key ] }
  end
end
