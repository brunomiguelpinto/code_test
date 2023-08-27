# frozen_string_literal: true

require 'csv'

# The MerchantImporterService is responsible for importing merchant data from a CSV file.
class MerchantImporterService
  # Constants for defining the batch size for bulk insert,
  # default currency for merchants, and CSV parsing configurations.
  BATCH_SIZE = 1000
  DEFAULT_CURRENCY = 'EUR'
  CSV_CONFIGS = {
    headers: true,
    col_sep: ';'
  }.freeze

  # Regular expression for sanitizing email addresses.
  EMAIL_REGEX = /[^a-zA-Z0-9_.@-]/i

  # Initializes a new instance of the service with a given CSV file path.
  def initialize(file_path)
    @file_path = file_path
    @logger = Rails.logger
  end

  # Primary method that processes and imports merchants from the given CSV file.
  def perform
    # Ensures the file exists, else logs an error.
    return @logger.error("File #{@file_path} does not exist.") unless File.exist?(@file_path)

    # Array to store merchants data temporarily for batch insertion.
    merchants_batch = []

    begin
      # Iterates over the CSV file row-by-row.
      CSV.foreach(@file_path, **CSV_CONFIGS) do |row|
        # Converts each CSV row to merchant attributes and appends to the batch.
        merchants_batch << build_merchant_data(row)

        # Checks if the batch reaches its size limit, and if so, performs the insertion.
        if merchants_batch.size >= BATCH_SIZE
          bulk_insert_merchants(merchants_batch)
          merchants_batch.clear
        end
      end

      # Handles any remaining merchants that didn't meet the batch size.
      bulk_insert_merchants(merchants_batch) unless merchants_batch.empty?

      # Logs successful import.
      @logger.info("Successfully imported merchants from #{@file_path}")
    rescue StandardError => e
      # Logs any exception that might occur during the process.
      @logger.error("Error while importing merchants: #{e.message}")
    end
  end

  private

  # Constructs merchant attributes from a CSV row.
  def build_merchant_data(row)
    {
      reference: row['reference'],
      email: sanitize_email(row['email']),
      live_on: Date.parse(row['live_on']),
      disbursement_frequency: row['disbursement_frequency'],
      minimum_monthly_fee_cents: (row['minimum_monthly_fee'].to_f * 100).to_i, # Converts fee to cents.
      currency: DEFAULT_CURRENCY
    }
  end

  # Cleans up the email string by removing unwanted characters.
  def sanitize_email(email)
    email.gsub(EMAIL_REGEX, '').downcase
  end

  # Performs bulk insertion of merchants in a transaction to ensure atomicity.
  def bulk_insert_merchants(merchants)
    ActiveRecord::Base.transaction do
      Merchant.insert_all(merchants)
    end
  rescue StandardError => e
    # Logs an error in case of a failed insertion.
    @logger.error("Error while performing bulk insert: #{e.message}")
  end
end
