# 「今日決める」画面の山札（DB には保存しない PORO）
# その日に出した場所（seen_ids）と、いま出している3件（hand_ids）をセッションの Hash で受け渡しする
#
#   deck = TodayDeck.new(session[:today], policy_scope(Place))
#   hand_ids = deck.current_hand(distance)
#   hand_ids = deck.draw(distance) if hand_ids.empty?
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

  # いま出している手札の place_id を返す（山札は進めない）。
  # 手札を引いたときと同じ距離感のときだけ、まだ候補に残っているものを返す。
  # 距離感が違う・手札が空（初回・引き切った・手札の場所がすべて削除された）なら []
  def current_hand(distance)
    return [] unless @state["distance"] == distance

    # セッションの id のうち、まだ候補に残っているものだけを手札とみなす
    hand_ids & @scope.where(id: hand_ids).ids
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
