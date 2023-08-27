class DisbursementWorker
  include Sidekiq::Worker

  def perform
    Merchant.find_each do |merchant|
      process_disbursements_for(merchant)
    end
  end

  private

  # Initiates the disbursement process for a given merchant.
  #
  # @param merchant [Merchant] The merchant for whom disbursements are being processed.
  def process_disbursements_for(merchant)
    oldest_order_date = oldest_unprocessed_order_date_for(merchant)
    return unless oldest_order_date

    date_iterator_for(merchant.disbursement_frequency, oldest_order_date) do |start_date, end_date|
      disburse_for_date_range(merchant, start_date, end_date)
    end
  end

  # Processes disbursements for orders within a specific date range.
  #
  # @param merchant [Merchant] The merchant for whom disbursements are being processed.
  # @param start_date [Date] The beginning of the date range.
  # @param end_date [Date] The end of the date range.
  def disburse_for_date_range(merchant, start_date, end_date)
    orders = fetch_unprocessed_orders_for(merchant, start_date, end_date)
    total_amount_cents = orders.sum(:amount)
    monthly_fee_cents = calculate_monthly_fee_for(merchant, start_date)

    if amount_or_fee_to_disburse?(total_amount_cents, monthly_fee_cents)
      create_and_link_disbursement(merchant, orders, total_amount_cents, end_date, monthly_fee_cents)
    end
  end

  # Calculates the monthly fee for a merchant based on their transactions.
  #
  # @param merchant [Merchant] The merchant for which the monthly fee is calculated.
  # @param date [Date] The reference date for calculating the monthly fee.
  # @return [Integer] The amount to be charged as the monthly fee in cents.
  def calculate_monthly_fee_for(merchant, date)
    return 0 unless eligible_for_monthly_fee?(merchant.disbursement_frequency, date)

    last_month_fee = total_fees_for_month(merchant, date.last_month)
    [merchant.minimum_monthly_fee_cents - last_month_fee, 0].max
  end

  # Calculates the total fees accrued by a merchant for a specific month based on their disbursements.
  #
  # This method fetches all the disbursements for the merchant within the given month's range and sums up the fee_cents from each disbursement.
  #
  # @param merchant [Merchant] The merchant for whom the fees need to be calculated.
  # @param date [Date] Any date within the month for which total fees are being calculated.
  #                    The method will use this date to determine the beginning and end of the month.
  # @return [Integer] The total fee in cents for the specified month.
  def total_fees_for_month(merchant, date)
    date_range = date.beginning_of_month..date.end_of_month
    merchant.disbursements.where(disbursed_on: date_range).sum(:fee_cents)
  end


  # Determines if a merchant is eligible for a monthly fee based on their disbursement frequency and a given date.
  #
  # A merchant with a 'DAILY' disbursement frequency is eligible on the first day of the month,
  # while a merchant with a 'WEEKLY' disbursement frequency is eligible during the first seven days of the month.
  #
  # @param disbursement_frequency [String] The merchant's disbursement frequency ('DAILY' or 'WEEKLY').
  # @param date [Date] The date to check eligibility against.
  # @return [Boolean] True if the merchant is eligible for a monthly fee, otherwise false.
  def eligible_for_monthly_fee?(disbursement_frequency, date)
    (disbursement_frequency == 'DAILY' && date.day == 1) ||
      (disbursement_frequency == 'WEEKLY' && date.day <= 7)
  end


  # Fetches unprocessed orders for a merchant within a given date range.
  #
  # @param merchant [Merchant] The relevant merchant.
  # @param start_date [Date] The beginning of the date range.
  # @param end_date [Date] The end of the date range.
  # @return [ActiveRecord::Relation] A collection of orders.
  def fetch_unprocessed_orders_for(merchant, start_date, end_date)
    merchant.orders.where(disbursement_id: nil, created_at: start_date..end_date)
  end

  # Creates a disbursement and links it with the relevant orders.
  #
  # @param merchant [Merchant] The relevant merchant.
  # @param orders [ActiveRecord::Relation] A collection of orders.
  # @param amount_cents [Integer] The total amount in cents.
  # @param disbursed_on [Date] The date the disbursement is being made.
  # @param monthly_fee [Integer] The monthly fee in cents.
  def create_and_link_disbursement(merchant, orders, amount_cents, disbursed_on, monthly_fee)
    fee_cents = calculate_disbursement_fee(amount_cents).cents
    disbursement = create_disbursement(merchant, amount_cents, fee_cents, disbursed_on, monthly_fee)
    orders.update_all(disbursement_id: disbursement.id)
  end

  # Iterates through dates based on a specified disbursement frequency.
  #
  # @param frequency [String] The disbursement frequency ("DAILY" or "WEEKLY").
  # @param start_date [Date] The starting date.
  def date_iterator_for(frequency, start_date)
    case frequency
    when 'DAILY'
      daily_iterator(start_date) { |s_date, e_date| yield s_date, e_date }
    when 'WEEKLY'
      weekly_iterator(start_date) { |s_date, e_date| yield s_date, e_date }
    end
  end

  # Iterates through each day from the start date until yesterday.
  #
  # @param start_date [Date] The starting date.
  def daily_iterator(start_date)
    (start_date..Date.yesterday).each do |date|
      yield date.beginning_of_day, date.end_of_day
    end
  end

  # Iterates through each week starting from the given date until the current week's start.
  #
  # @param start_date [Date] The starting date.
  def weekly_iterator(start_date)
    current_week_start = Date.today.beginning_of_week
    while start_date < current_week_start
      yield start_date, start_date.end_of_week.end_of_day
      start_date += 7.days
    end
  end

  # Fee calculation methods

  # Calculates the disbursement fee for a given amount.
  #
  # @param amount_cents [Integer] The amount in cents for which the fee is being calculated.
  # @return [Money] The calculated fee.
  def calculate_disbursement_fee(amount_cents)
    percentage = case amount_cents
                 when 0...5000 then 0.01
                 when 5000...30000 then 0.0095
                 else 0.0085
                 end

    Money.new((amount_cents * percentage).ceil)
  end

  # Utility methods

  # Determines the oldest order date for a merchant that hasn't been processed.
  #
  # @param merchant [Merchant] The relevant merchant.
  # @return [Date, nil] The oldest unprocessed order date or nil if no orders found.
  def oldest_unprocessed_order_date_for(merchant)
    merchant.orders.where(disbursement_id: nil).order(:created_at).first&.created_at&.to_date
  end

  # Checks if there's an amount or fee to be disbursed.
  #
  # @param amount_cents [Integer] The amount in cents.
  # @param monthly_fee_cents [Integer] The monthly fee in cents.
  # @return [Boolean] True if there's an amount or fee to disburse, otherwise false.
  def amount_or_fee_to_disburse?(amount_cents, monthly_fee_cents)
    amount_cents.positive? || monthly_fee_cents.positive?
  end

  # Creates a disbursement record.
  #
  # @param merchant [Merchant] The relevant merchant.
  # @param amount_cents [Integer] The disbursement amount in cents.
  # @param fee_cents [Integer] The fee in cents.
  # @param disbursed_on [Date] The date the disbursement is being made.
  # @param monthly_fee [Integer] The monthly fee in cents.
  # @return [Disbursement] The created disbursement record.
  def create_disbursement(merchant, amount_cents, fee_cents, disbursed_on, monthly_fee)
    Disbursement.create!(
      merchant: merchant,
      amount_cents: amount_cents - fee_cents,
      fee_cents: fee_cents,
      monthly_fee_cents: monthly_fee,
      disbursed_on: disbursed_on
    )
  end
end
