# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrderImporterService do
  describe '#perform' do
    let(:file_path) { 'path_to_file.csv' } # Replace with actual test CSV path
    let(:service) { OrderImporterService.new(file_path) }

    let!(:merchant1) { create(:merchant, reference: 'MERCHANT1', id: 1) }
    let!(:merchant2) { create(:merchant, reference: 'MERCHANT2', id: 2) }

    describe 'with a valid CSV file' do
      before do
        stub_valid_csv
      end

      it 'imports orders from the CSV file' do
        expect { service.perform }.to change(Order, :count).by(2)
      end
    end

    describe 'with a missing merchant reference' do
      before do
        stub_invalid_csv_missing_merchant
      end

      it 'does not import orders with missing merchant references' do
        expect { service.perform }.not_to change(Order, :count)
      end
    end

    describe 'with an invalid CSV format' do
      before do
        stub_malformed_csv
      end

      it 'logs an error and does not import any orders' do
        expect(Rails.logger).to receive(:error).with(match(/Error while importing orders:/))
        expect { service.perform }.not_to change(Order, :count)
      end
    end

    # Helper methods for stubbing CSV data
    def stub_valid_csv
      allow(CSV).to receive(:foreach).and_yield(
        { 'merchant_reference' => merchant1.reference, 'amount' => '10.5', 'created_at' => '2022-01-01' }
      ).and_yield(
        { 'merchant_reference' => merchant2.reference, 'amount' => '15.5', 'created_at' => '2022-01-02' }
      )
    end

    def stub_invalid_csv_missing_merchant
      allow(CSV).to receive(:foreach).and_yield(
        { 'merchant_reference' => 'MISSING_MERCHANT', 'amount' => '10.5', 'created_at' => '2022-01-01' }
      )
    end

    def stub_malformed_csv
      allow(CSV).to receive(:foreach).and_raise(CSV::MalformedCSVError)
    end
  end
end
