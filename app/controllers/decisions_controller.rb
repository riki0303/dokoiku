# 今日決める画面。現在のグループの場所から3件を出す
class DecisionsController < ApplicationController
  def show
    authorize :decision, :show?
    @distance = distance_param
    # 0件のとき「まだ場所がない」のか「今日の候補を引き切った（またはすべて消化した）」のかを出し分けるため、
    # ここだけは消化済みの場所も数える
    @any_places = policy_scope(Place).exists?
    # 候補はストックに残っている場所だけ（消化済みの場所は出さない）
    stock = policy_scope(Place).in_stock

    deck = TodayDeck.new(session[:today], stock)
    hand_ids = deck.current_hand(@distance)
    # 再読み込みや距離感の切り替えでは、その距離感で覚えている手札を出す（山札は進めない）。
    # 手札がなければ（初回・引き切り・手札の場所がすべて削除や他の距離感で見送られた）新しく引く
    hand_ids = deck.draw(@distance) if hand_ids.empty?
    session[:today] = deck.to_h
    # セッションの id は信用せず、自分のグループのストックから取り直す（引いたあとに削除・消化された場所は出さない）
    @places = stock.in_order_of(:id, hand_ids)
  end

  # 「別の3件」。いま出している手札を見送ってセッションの山札を進めるため POST にし、
  # 再読み込みで引き直さないよう GET の画面へリダイレクトする
  def redraw
    authorize :decision, :redraw?
    distance = distance_param
    deck = TodayDeck.new(session[:today], policy_scope(Place).in_stock)
    deck.redraw(distance)
    session[:today] = deck.to_h
    redirect_to root_path(distance: distance), status: :see_other
  end

  private

  # 距離感の絞り込み。nil は「すべて」。一覧にない値（"xxx" や配列など）もエラーにせず「すべて」として扱う
  def distance_param
    params[:distance].presence_in(Place.distances.keys)
  end
end
