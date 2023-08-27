# frozen_string_literal: true

# spec/factories/merchants.rb

FactoryBot.define do
  factory :merchant do
    reference { SecureRandom.hex(10) } # Generates a random reference string.
    email { Faker::Internet.email } # Generates a unique email using the Faker gem.
    live_on { Date.today }
    disbursement_frequency { Merchant::DISBURSEMENT_FREQUENCIES.sample } # Picks either 'DAILY' or 'WEEKLY' at random.
    minimum_monthly_fee_cents { rand(1000..10_000) } # Generates a random value between 1000 and 10000.
    currency { 'EUR' }
  end
end
