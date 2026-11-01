class PlacesController < ApplicationController
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

  def place_params
    params.expect(place: %i[name note distance])
  end
end
