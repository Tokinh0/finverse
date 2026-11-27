module Api::V1
  class AlertsController < ApplicationController
    # GET /alerts?month=YYYY-MM&include_dismissed=true (month defaults to the latest one with debits)
    def index
      detector = Alerts::Detector.new(month: params[:month], include_dismissed: params[:include_dismissed])
      alerts = detector.call

      render json: {
        month: detector.month&.strftime("%Y-%m"),
        alerts: alerts.map do |alert|
          {
            kind: alert.kind,
            message: alert.message,
            details: alert.details,
            dismissed: alert.dismissed,
            transaction: TransactionPresenter.new(alert.transaction)
          }
        end
      }
    end

    # POST /alerts/dismiss { transaction_id, kind }
    def dismiss
      dismissal = AlertDismissal.find_or_initialize_by(parsed_transaction_id: params.require(:transaction_id), kind: params.require(:kind))

      if dismissal.save
        head :no_content
      else
        render json: { errors: dismissal.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /alerts/dismiss { transaction_id, kind } brings an alert back
    def restore
      AlertDismissal.where(parsed_transaction_id: params.require(:transaction_id), kind: params.require(:kind)).delete_all
      head :no_content
    end
  end
end
