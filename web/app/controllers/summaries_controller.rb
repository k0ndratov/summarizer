class SummariesController < ApplicationController
  def index
    @summaries = Summary.order(created_at: :desc).limit(50)
  end

  def new
    @summary = Summary.new
  end

  def create
    @summary = Summary.new(summary_params)
    if @summary.save
      TranscribeJob.perform_later(@summary.id)
      redirect_to @summary
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @summary = Summary.find(params[:id])
  end

  private

  def summary_params
    params.require(:summary).permit(:source_url)
  end
end
