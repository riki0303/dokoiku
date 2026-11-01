class PlacesController < ApplicationController
  def index
    authorize Place
    # 自分のグループに絞ったあとに ransack をかけるため、q に何を送っても他グループの場所は出ない
    own_places = policy_scope(Place)
    @q = own_places.ransack(search_params)
    @places = @q.result.order(created_at: :desc)
    # 0件のとき「まだ場所がない」のか「絞り込んだ結果だけ0件」なのかを出し分けるため
    @any_places = own_places.exists?
  end

  def new
    @place = current_group.places.build
    authorize @place
  end

  def create
    @place = current_group.places.build(place_params)
    authorize @place

    if @place.save
      redirect_to new_place_path, notice: "#{@place.name}を登録しました"
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  # ransack に渡す検索条件。距離感の絞り込みだけを受け付け、配列など想定外の形の値は捨てる（そのまま渡すと SQL 組み立て時にエラーになるため）
  def search_params
    params.permit(q: %i[distance_eq])[:q]
  end

  def place_params
    params.expect(place: %i[name note distance])
  end
end
