class DistributionsController < ApplicationController
  # Distribution list is insensitive information, no login needed therefore
  skip_before_filter :extract_user, :only => [:index, :show]
  before_filter :require_admin, :except => [:index, :show]

  validate_action :index => {:method => :get, :response => :distributions}
  validate_action :upload => {:method => :put, :request => :distributions, :response => :status}


  # GET /distributions
  # GET /distributions.xml
  def index
    @distributions = Distribution.all

    respond_to do |format|
      format.xml
      format.json { render :json => @distributions }
    end
  end

  # GET /distributions/opensuse-11.4
  # GET /distributions/opensuse-11.4.xml
  def show
    @distribution = Distribution.find(params[:id])

    respond_to do |format|
      format.xml  { render :xml => @distribution }
      format.json { render :json => @distribution }
    end
  end

  # basically what the other parts of our API would look like
  def upload 
    raise 'routes broken' unless request.put?
    req = Xmlhash.parse(request.body.read)
    unless req
      render_error :message => "Invalid XML",
                   :status => 400, :errorcode => "invalid_xml"
      return
    end
    @distributions = Distribution.parse(req)
    render_ok
  end

  # POST /distributions
  # POST /distributions.xml
  def create
    @distribution = Distribution.new(params[:distribution])

    respond_to do |format|
      if @distribution.save
        format.xml  { render xml: @distribution, :status => :created, :location => @distribution }
        format.json { render json: @distribution, :status => :created, :location => @distribution }
      else
        format.xml  { render :xml => @distribution.errors, :status => :unprocessable_entity }
        format.json { render :json => @distribution.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /distributions/opensuse-11.4
  # DELETE /distributions/opensuse-11.4.xml
  def destroy
    @distribution = Distribution.find(params[:id])
    @distribution.destroy

    respond_to do |format|
      format.xml  { head :ok }
      format.json { head :ok }
    end
  end
end
