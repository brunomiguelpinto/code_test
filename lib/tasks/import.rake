# frozen_string_literal: true

# This namespace groups import-related tasks.
namespace :import do
  # Rake task to process and import merchants from a predefined CSV file.
  desc 'Process merchants from CSV file'
  task merchants: :environment do
    # Define the path to the CSV file containing merchant data.
    file_path = 'public/seeds/merchants.csv'

    # Instantiate the MerchantImporterService with the file path and perform the import.
    MerchantImporterService.new(file_path).perform
  end

  # Rake task to process and import orders from a predefined CSV file.
  desc 'Import orders from a CSV file'
  task orders: :environment do
    # Define the path to the CSV file containing order data.
    file_path = 'public/seeds/orders.csv'

    # Instantiate the OrderImporterService with the file path and perform the import.
    OrderImporterService.new(file_path).perform
  end
end
