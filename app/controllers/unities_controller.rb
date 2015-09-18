class UnitiesController < ApplicationController
  has_scope :page, default: 1
  has_scope :per, default: 10

  def index
    @unities = apply_scopes(Unity.filter(filtering_params(params[:search]))).ordered

    authorize @unities
  end

  def new
    @unity = Unity.new unit_type: 'school_unit'
    @unity.build_address unless @unity.address

    authorize @unity
  end

  def show
    @unities = Unity.all 
    render json:  @unities
  end

  def create
    @unity = Unity.new(unity_params)
    @unity.author = current_user

    authorize @unity

    if @unity.save
      respond_with @unity, location: unities_path
    else
      render :new
    end
  end

  def edit
    @unity = Unity.find(params[:id])
    @unity.build_address unless @unity.address

    authorize @unity
  end

  def update
    @unity = Unity.find(params[:id])

    authorize @unity

    if @unity.update(unity_params)
      respond_with @unity, location: unities_path
    else
      render :edit
    end
  end

  def destroy
    @unity = Unity.find(params[:id])

    authorize @unity

    @unity.destroy

    respond_with @unity, location: unities_path
  end

  def destroy_batch
    @unities = Unity.where(id: params[:ids])

    if @unities.destroy_all
      render json: {}, status: :ok
    else
      render json: {}, status: 500
    end
  end

  def history
    @unity = Unity.find params[:id]

    authorize @unity

    respond_with @unity
  end

  def synchronizations
    @unities = UnitiesParser.parse!(IeducarApiConfiguration.current)

    authorize Unity, :create?
  end

  def create_batch
    if UnitiesCreator.create!(params[:unities])
      redirect_to unities_path, notice: t('flash.unities.create_batch.notice')
    else
      redirect_to synchroniation_unities_path, alert: t('flash.unities.create_batch.alert')
    end
  end

  private

  def unity_params
    params.require(:unity).permit(
      :name, :phone, :email, :responsible, :api_code, :unit_type, :active,
      :address_attributes => [
        :id, :zip_code, :street, :number, :complement, :neighborhood, :city,
        :state, :country, :latitude, :longitude, :_destroy
      ]
    )
  end

  def filtering_params(params)
    if params
      params.slice(:search_name, :unit_type, :phone, :email, :responsible)
    else
      {}
    end
  end
end
