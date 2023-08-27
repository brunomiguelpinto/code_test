require 'rails_helper'

RSpec.describe DisbursementWorker, type: :worker do
  let!(:merchant) { create(:merchant, disbursement_frequency: 'DAILY') }
  let!(:order) { create(:order, merchant: merchant, disbursement_id: nil, created_at: Date.yesterday) }

  describe '#perform' do
    subject { described_class.new.perform }

    it 'processes disbursements for each merchant' do
      expect_any_instance_of(described_class).to receive(:process_disbursements_for).with(merchant)
      subject
    end
  end

  describe '#process_disbursements_for' do
    let(:start_date) { Date.yesterday.beginning_of_day }
    let(:end_date) { Date.yesterday.end_of_day }
    subject { described_class.new.send(:process_disbursements_for, merchant) }

    context 'with eligible merchant' do
      it 'disburses for the relevant date range' do
        expect_any_instance_of(described_class).to receive(:disburse_for_date_range).with(merchant, start_date, end_date)
        subject
      end
    end

    context 'with ineligible merchant' do
      before do
        allow_any_instance_of(described_class).to receive(:oldest_unprocessed_order_date_for).and_return(nil)
      end

      it 'does not disburse for the merchant' do
        expect_any_instance_of(described_class).not_to receive(:disburse_for_date_range)
        subject
      end
    end
  end

  let!(:merchant) { create(:merchant, disbursement_frequency: 'DAILY') }
  let!(:order) { create(:order, merchant: merchant, disbursement_id: nil, created_at: Date.yesterday) }

  describe '#perform' do
    subject { described_class.new.perform }

    it 'processes disbursements for each merchant' do
      expect_any_instance_of(described_class).to receive(:process_disbursements_for).with(merchant)
      subject
    end
  end

  describe '#process_disbursements_for' do
    let(:start_date) { Date.yesterday.beginning_of_day }
    let(:end_date) { Date.yesterday.end_of_day }
    subject { described_class.new.send(:process_disbursements_for, merchant) }

    context 'with eligible merchant' do
      it 'disburses for the relevant date range' do
        expect_any_instance_of(described_class).to receive(:disburse_for_date_range).with(merchant, start_date, end_date)
        subject
      end
    end

    context 'with ineligible merchant' do
      before do
        allow_any_instance_of(described_class).to receive(:oldest_unprocessed_order_date_for).and_return(nil)
      end

      it 'does not disburse for the merchant' do
        expect_any_instance_of(described_class).not_to receive(:disburse_for_date_range)
        subject
      end
    end
  end

  describe '#eligible_for_monthly_fee?' do
    subject { described_class.new.send(:eligible_for_monthly_fee?, merchant.disbursement_frequency, date) }

    context 'with DAILY frequency' do
      let(:date) { Date.new(2023, 1, 1) } # First day of the month
      it { is_expected.to be_truthy }
    end

    context 'with WEEKLY frequency after first seven days' do
      let(:date) { Date.new(2023, 1, 10) }
      it { is_expected.to be_falsey }
    end
  end

  describe '#oldest_unprocessed_order_date_for' do
    subject { described_class.new.send(:oldest_unprocessed_order_date_for, merchant) }

    context 'with unprocessed orders' do
      it 'returns the oldest order date' do
        expect(subject).to eq(order.created_at.to_date)
      end
    end
  end

  describe '#amount_or_fee_to_disburse?' do
    subject { described_class.new.send(:amount_or_fee_to_disburse?, amount_cents, monthly_fee_cents) }

    context 'with a positive amount and zero monthly fee' do
      let(:amount_cents) { 5000 }
      let(:monthly_fee_cents) { 0 }
      it { is_expected.to be_truthy }
    end

    context 'with zero amount and positive monthly fee' do
      let(:amount_cents) { 0 }
      let(:monthly_fee_cents) { 500 }
      it { is_expected.to be_truthy }
    end

    context 'with both zero amount and monthly fee' do
      let(:amount_cents) { 0 }
      let(:monthly_fee_cents) { 0 }
      it { is_expected.to be_falsey }
    end
  end
end
