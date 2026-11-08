class PlacesController < ApplicationController
  before_action :set_place, only: %i[edit update destroy]

  def index
    authorize Place
    wanted_places = policy_scope(Place).wanted
    @any_places = wanted_places.exists?
    @q = wanted_places.ransack(search_params)
    @places = @q.result.order(created_at: :desc)
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

  def edit; end

  def update
    if @place.update(place_params)
      redirect_to places_path, notice: "#{@place.name}を更新しました"
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @place.destroy!
    # Turbo が DELETE のあとに一覧を GET で開き直せるよう、303 See Other でリダイレクトする
    redirect_to places_path, notice: "#{@place.name}を削除しました", status: :see_other
  end

  private

  # 自分のグループの場所から探すため、他のグループの id を指定すると RecordNotFound（404）になる
  def set_place
    @place = policy_scope(Place).find(params[:id])
    authorize @place
  end

  # ransack に渡す検索条件。距離感の絞り込みだけを受け付け、配列など想定外の形の値は捨てる（そのまま渡すと SQL 組み立て時にエラーになるため）
  def search_params
    params.permit(q: %i[distance_eq])[:q]
  end

  def place_params
    params.expect(place: %i[name note distance])
  end
end
