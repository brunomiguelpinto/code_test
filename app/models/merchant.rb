# frozen_string_literal: true

# This is the Merchant model representing merchants using the system.
class Merchant < ApplicationRecord
  # Constants

  # Define constants for disbursement frequencies to avoid magic strings and maintain consistency.
  DAILY = 'DAILY'
  WEEKLY = 'WEEKLY'

  # A list of allowed disbursement frequencies.
  DISBURSEMENT_FREQUENCIES = [DAILY, WEEKLY].freeze

  # Validations

  # Ensures that each merchant has a unique reference.
  validates :reference, presence: true, uniqueness: true

  # Ensures that email is present and matches a standard email format.
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Validates that the disbursement frequency is either 'DAILY' or 'WEEKLY'.
  validates :disbursement_frequency, presence: true, inclusion: { in: DISBURSEMENT_FREQUENCIES }

  # Associations

  # A merchant can have many orders.
  has_many :orders

  # A merchant can have many disbursements.
  has_many :disbursements

  # Configuration for the Money gem, setting up the money attribute with the relevant currency.
  monetize :minimum_monthly_fee_cents, with_model_currency: :currency
end
