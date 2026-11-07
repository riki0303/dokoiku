# 「今日決める」画面の山札（DB には保存しない PORO）
# その日に「別の3件」で見送った場所（seen_ids）と、距離感ごとにいま出している手札（hands）を
# セッションの Hash で受け渡しする
#
#   deck = TodayDeck.new(session[:today], policy_scope(Place).in_stock)
#   hand_ids = deck.current_hand(distance)
#   hand_ids = deck.draw(distance) if hand_ids.empty?
#   session[:today] = deck.to_h
#
# 「別の3件」では、いまの手札を見送ってから次の手札を引く
#
#   deck.redraw(distance)
class TodayDeck
  HAND_SIZE = 3
  # 「すべて」（distance が nil）の手札のキー。セッションは JSON（Cookie）を経由するため、
  # nil をキーにすると "" に変わってしまう。距離感の値と被らない固定の文字列にする
  ALL_KEY = "all".freeze

  # state: セッションに入れていた Hash（初回は nil）。キーは Cookie を経由すると文字列になるため、文字列で扱う
  # scope: 候補にする場所（現在のグループのストックに絞ったもの）
  def initialize(state, scope, today: Date.current)
    @scope = scope
    @state = state.to_h.stringify_keys
    # 日付が変わった（または初回）なら山札を空にする
    reset(today.iso8601) unless @state["date"] == today.iso8601
  end

  # その距離感でいま出している手札の place_id を返す（山札は進めない）。
  # まだ候補に残っているものだけを、手札の順序のまま返す。
  # 削除された・他の距離感で見送った・距離感が変わった場所は外れ、補充はしない
  def current_hand(distance)
    ids = hand_ids(distance)
    return [] if ids.empty?

    ids & candidates(distance).where(id: ids).ids
  end

  # まだ見送っていない場所から、その距離感の手札を最大3件ランダムに引いて覚える。
  # 引いただけでは山札を進めない（距離感を切り替えるだけで候補が減らないようにするため）
  def draw(distance)
    ids = candidates(distance).ids.sample(HAND_SIZE)
    hands[hand_key(distance)] = ids
    ids
  end

  # 「別の3件」。その距離感でいま出している手札を見送り（山札を進め）、次の手札を引く
  def redraw(distance)
    @state["seen_ids"] = seen_ids | current_hand(distance)
    draw(distance)
  end

  # セッションに書き戻すための Hash
  def to_h
    @state
  end

  private

  def reset(date)
    @state = { "date" => date, "seen_ids" => [], "hands" => {} }
  end

  # まだ見送っていない場所。距離感を指定するとその距離感だけに絞る
  def candidates(distance)
    scope = @scope.where.not(id: seen_ids)
    distance ? scope.where(distance: distance) : scope
  end

  def seen_ids
    Array(@state["seen_ids"])
  end

  def hands
    @state["hands"] ||= {}
  end

  def hand_ids(distance)
    Array(hands[hand_key(distance)])
  end

  def hand_key(distance)
    distance || ALL_KEY
  end
end
