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

  # GET /summaries/:id            → page
  # GET /summaries/:id.{srt,txt,md,json} → file download (only once done)
  def show
    @summary = Summary.find(params[:id])
    format = params[:format]&.to_sym
    return if format.nil? || format == :html
    return head :not_found unless Exporters::FORMATS.key?(format)
    return head :conflict unless @summary.done?

    send_data Exporters.render(@summary, format),
              type: Exporters.mime(format),
              filename: "summary-#{@summary.id}.#{format}",
              disposition: :attachment
  end

  private

  def summary_params
    params.require(:summary).permit(:source_url)
  end
end
