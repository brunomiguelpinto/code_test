# frozen_string_literal: true

# app/services/order_importer_service.rb
class OrderImporterService
  # Required to read CSV files.
  require 'csv'

  # Constants to represent the batch size and configurations for reading the CSV.
  BATCH_SIZE = 10_000
  CSV_CONFIGS = {
    headers: true,
    col_sep: ';'
  }.freeze

  # Initializes the OrderImporterService with a given file path.
  #
  # @param file_path [String] The path to the CSV file to be imported.
  def initialize(file_path)
    @file_path = file_path
    @logger = Rails.logger
  end

  # The primary method that orchestrates the CSV reading and order importing.
  def perform
    # Create a mapping of merchant references to their respective IDs for quick lookup.
    merchant_ids_by_reference = fetch_merchant_ids_by_reference

    # Temporary storage for orders that will be imported in batches.
    orders_to_import = []

    # Use a transaction to ensure data integrity.
    ActiveRecord::Base.transaction do
      # Iterate over each row in the CSV file.
      CSV.foreach(@file_path, **CSV_CONFIGS) do |row|
        # Build an order instance for the current CSV row.
        order = build_order(row, merchant_ids_by_reference)
        orders_to_import << order if order

        # If the current batch reaches the defined size, import the batch and clear the temporary storage.
        bulk_insert_orders(orders_to_import) if orders_to_import.size >= BATCH_SIZE
      end

      # After iterating through the CSV, import any remaining orders.
      bulk_insert_orders(orders_to_import) unless orders_to_import.empty?
    end
  rescue StandardError => e
    # Log any errors that arise during the process.
    @logger.error("Error while importing orders: #{e.message}")
  end

  private

  # Fetch a mapping of merchant references to their IDs.
  #
  # @return [Hash] A hash where keys are merchant references and values are their respective IDs.
  def fetch_merchant_ids_by_reference
    Merchant.pluck(:reference, :id).to_h
  end

  # Constructs an order instance based on a CSV row.
  #
  # @param row [CSV::Row] The current CSV row being processed.
  # @param merchant_ids_by_reference [Hash] A mapping of merchant references to their IDs.
  # @return [Order, nil] An order instance if a valid merchant reference is found, otherwise nil.
  def build_order(row, merchant_ids_by_reference)
    merchant_id = merchant_ids_by_reference[row['merchant_reference']]
    return unless merchant_id

    order_amount_in_cents = (row['amount'].to_f * 100).to_i
    Order.new(
      merchant_id:,
      amount: order_amount_in_cents,
      created_at: Date.parse(row['created_at'])
    )
  end

  # Performs the actual bulk insertion of orders into the database.
  #
  # @param orders [Array<Order>] An array of order instances to be imported.
  def bulk_insert_orders(orders)
    Order.import orders
    orders.clear
  end
end
