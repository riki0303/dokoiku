module VisitsHelper
  # 「また行きたいか」の表示用ラベル（はい / いいえ）
  def want_again_label(want_again)
    want_again ? "はい" : "いいえ"
  end
end
