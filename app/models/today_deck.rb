# 「今日決める」画面の山札（DB には保存しない PORO）
# その日に出した場所（seen_ids）と、いま出している3件（hand_ids）をセッションの Hash で受け渡しする
#
#   deck = TodayDeck.new(session[:today], policy_scope(Place))
#   hand_ids = deck.hand(distance)
#   session[:today] = deck.to_h
class TodayDeck
  HAND_SIZE = 3

  # state: セッションに入れていた Hash（初回は nil）。キーは Cookie を経由すると文字列になるため、文字列で扱う
  # scope: 候補にする場所（現在のグループに絞ったもの）
  def initialize(state, scope, today: Date.current)
    @scope = scope
    @state = state.to_h.stringify_keys
    # 日付が変わった（または初回）なら山札を空にする
    reset(today.iso8601) unless @state["date"] == today.iso8601
  end

  # 手札の place_id を返す。手札を引いたときと同じ距離感なら同じ手札を返し（再読み込みで山札を減らさない）、
  # 距離感が違う・手札が空（引き切った・手札の場所がすべて削除された）なら新しく引く
  def hand(distance)
    if @state["distance"] == distance
      # セッションの id のうち、まだ候補に残っているものだけを手札とみなす
      remaining = hand_ids & @scope.where(id: hand_ids).ids
      return remaining if remaining.any?
    end

    draw(distance)
  end

  # まだ出していない場所から、次の手札を最大3件ランダムに引く。距離感を指定するとその距離感だけから引く
  def draw(distance)
    candidates = @scope.where.not(id: seen_ids)
    candidates = candidates.where(distance: distance) if distance
    ids = candidates.ids.sample(HAND_SIZE)
    @state.merge!("seen_ids" => seen_ids + ids, "hand_ids" => ids, "distance" => distance)
    ids
  end

  # セッションに書き戻すための Hash
  def to_h
    @state
  end

  private

  def reset(date)
    @state = { "date" => date, "seen_ids" => [], "hand_ids" => [], "distance" => nil }
  end

  def seen_ids
    Array(@state["seen_ids"])
  end

  def hand_ids
    Array(@state["hand_ids"])
  end
end
