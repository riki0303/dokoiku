# 今日決める画面。現在のグループの場所から3件を出す
class DecisionsController < ApplicationController
  def show
    authorize :decision, :show?
    @distance = distance_param
    own_places = policy_scope(Place)
    # 0件のとき「まだ場所がない」のか「今日の候補を引き切った」のかを出し分けるため
    @any_places = own_places.exists?

    deck = TodayDeck.new(session[:today], own_places)
    hand_ids = deck.hand(@distance)
    session[:today] = deck.to_h
    # セッションの id は信用せず、自分のグループの場所から取り直す（引いたあとに削除された場所は出さない）
    @places = own_places.in_order_of(:id, hand_ids)
  end

  # 「別の3件」。セッションの山札を進めるため POST にし、再読み込みで引き直さないよう GET の画面へリダイレクトする
  def redraw
    authorize :decision, :redraw?
    distance = distance_param
    deck = TodayDeck.new(session[:today], policy_scope(Place))
    deck.draw(distance)
    session[:today] = deck.to_h
    redirect_to root_path(distance: distance), status: :see_other
  end

  private

  # 距離感の絞り込み。nil は「すべて」。一覧にない値（"xxx" や配列など）もエラーにせず「すべて」として扱う
  def distance_param
    params[:distance].presence_in(Place.distances.keys)
  end
end
