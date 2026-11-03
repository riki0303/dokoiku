module DecisionsHelper
  # 場所の名前で検索する Google マップの URL
  def google_maps_search_url(place)
    "https://www.google.com/maps/search/?api=1&query=#{ERB::Util.url_encode(place.name)}"
  end

  # 登録からの経過期間（例：「3ヶ月前に登録」）。
  # rails_best_practices はキャッシュした画面で古い表記が残るのを避けるため time_ago_in_words を禁止しているが、この画面はキャッシュしないため使う
  def registered_ago(place)
    "#{time_ago_in_words(place.created_at)}前に登録" # rails_best_practices:disable NotUseTimeAgoInWordsCheck
  end
end
