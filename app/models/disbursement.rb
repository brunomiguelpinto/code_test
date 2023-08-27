# frozen_string_literal: true

# This is the Disbursement model representing disbursements made to merchants.
class Disbursement < ApplicationRecord
  # Each disbursement is associated with one merchant.
  belongs_to :merchant

  # A disbursement can be associated with many orders.
  has_many :orders

  # Validations to ensure that the required attributes are present.
  validates :amount_cents, :fee_cents, :disbursed_on, :reference, presence: true

  # Ensures that the reference of each disbursement is unique.
  validates :reference, uniqueness: true

  # Before saving a new disbursement to the database,
  # this callback ensures a unique reference is generated.
  before_validation :generate_unique_reference, on: :create

  private

  # This method is used to generate a unique reference for the disbursement.
  # It consists of the merchant's ID, the disbursement date, and a random hex value.
  # The `||=` ensures that it only sets the reference if it's currently nil,
  # to avoid overwriting an existing reference.
  def generate_unique_reference
    self.reference ||= "#{merchant.id}-#{disbursed_on}-#{SecureRandom.hex(4)}"
  end
end
