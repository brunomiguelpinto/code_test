# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Merchant, type: :model do
  # Let's set up a sample merchant for use in the tests
  let(:merchant) { build(:merchant) }

  describe 'database columns' do
    it { is_expected.to have_db_column(:reference).of_type(:string).with_options(null: false) }
    it { is_expected.to have_db_column(:email).of_type(:string).with_options(null: false) }
    it { is_expected.to have_db_column(:live_on).of_type(:date) }
    it { is_expected.to have_db_column(:disbursement_frequency).of_type(:string) }
    it { is_expected.to have_db_column(:minimum_monthly_fee_cents).of_type(:integer) }
    it { is_expected.to have_db_column(:currency).of_type(:string) }
  end

  describe 'validations' do
    subject { FactoryBot.build(:merchant) }
    it { is_expected.to validate_presence_of(:reference) }
    it { is_expected.to validate_uniqueness_of(:reference) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to allow_value('test@example.com').for(:email) }
    it { is_expected.not_to allow_value('invalid_email').for(:email) }
    it { is_expected.to validate_presence_of(:disbursement_frequency) }
    it { is_expected.to validate_inclusion_of(:disbursement_frequency).in_array(Merchant::DISBURSEMENT_FREQUENCIES) }
  end

  describe 'monetize configuration' do
    it 'monetizes minimum_monthly_fee' do
      merchant = create(:merchant)
      expect(merchant.minimum_monthly_fee_cents).to be_a(Integer)
      expect(merchant.minimum_monthly_fee).to be_a(Money)
      expect(merchant.minimum_monthly_fee.currency.to_s).to eq(merchant.currency)
    end
  end
end
