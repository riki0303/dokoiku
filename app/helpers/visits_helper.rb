module VisitsHelper
  # 「また行きたいか」の選択肢。[ラベル, 値] の配列を返す
  def want_again_options
    [ [ "はい", true ], [ "いいえ", false ] ]
  end

  # 「また行きたいか」の表示用ラベル（はい / いいえ）
  def want_again_label(want_again)
    want_again ? "はい" : "いいえ"
  end
end
