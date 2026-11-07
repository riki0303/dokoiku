class VisitsController < ApplicationController
  before_action :set_place, only: %i[new create]

  def index
    authorize Visit
    @visits = policy_scope(Visit).includes(:place).order(visited_on: :desc, created_at: :desc)
  end

  def new
    @visit = @place.visits.build(visited_on: Date.current)
    authorize @visit
  end

  def create
    @visit = @place.visits.build(visit_params)
    authorize @visit

    if @visit.save
      redirect_to places_path, notice: created_message
    else
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    # 自分のグループの記録から探すため、他のグループの id を指定すると RecordNotFound（404）になる
    visit = policy_scope(Visit).find(params[:id])
    authorize visit
    visit.destroy!
    redirect_to visits_path, notice: "#{visit.place_name}の訪問記録を取り消しました", status: :see_other
  end

  private

  # 消化済みの場所は in_stock で見つからない扱い（404）にする。グループのチェックは authorize で行う
  def set_place
    @place = Place.in_stock.find(params[:place_id])
  end

  def visit_params
    params.expect(visit: %i[visited_on want_again])
  end

  # 「いいえ」ならストックから外れ、「はい」ならストックに残ることを伝える
  def created_message
    if @visit.want_again
      "#{@place.name}の訪問を記録しました（ストックに残ります）"
    else
      "#{@place.name}を訪問済みにしました"
    end
  end
end
