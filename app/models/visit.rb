# 訪問記録。「また行きたいか」が「いいえ」の記録が付いた場所は行きたい場所から外れる（消化済み）。
# 「はい」なら行きたい場所に残り、次に行ったときにまた記録できるため、1つの場所に何件でも付けられる
class Visit < ApplicationRecord
  belongs_to :place

  # 訪問済み一覧や完了メッセージで場所の情報を出すため（visit.place_name のように呼ぶ）
  delegate :name, :note, :distance, to: :place, prefix: true

  # 明日以降の日付は記録させない（今日は Date.current で、config.time_zone の日本時間で判定する）。
  # 未入力は presence の「入力してください」だけを出すため、比較では nil を対象外にしてエラーの重複を避ける
  validates :visited_on, presence: true,
    comparison: { less_than_or_equal_to: -> { Date.current }, allow_nil: true, message: "は今日以前の日付を入力してください" }
  # boolean に presence を使うと false（いいえ）がエラーになるため、inclusion で未選択（nil）だけを弾く
  validates :want_again, inclusion: { in: [ true, false ], message: "を選択してください" }
end
