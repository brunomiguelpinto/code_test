# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MerchantImporterService do
  let(:test_file_path) { Rails.root.join('spec', 'fixtures', 'test_merchants.csv') }
  let(:service) { described_class.new(test_file_path) }

  before do
    # Stubbing Rails.logger to avoid console logs during tests.
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:info)
  end

  describe '#perform' do
    context 'when the file does not exist' do
      let(:test_file_path) { 'non_existent_file.csv' }

      it 'logs an error' do
        expect(Rails.logger).to receive(:error).with("File #{test_file_path} does not exist.")
        service.perform
      end

      it 'does not import any merchants' do
        expect { service.perform }.not_to change(Merchant, :count)
      end
    end

    context 'when the file exists' do
      # You can create a fixture CSV file `test_merchants.csv` in `spec/fixtures` with test data.
      it 'imports merchants from the CSV file' do
        # Assuming you have 10 merchants in your test CSV
        expect { service.perform }.to change(Merchant, :count).by(10)
      end
    end
  end

  describe '#sanitize_email' do
    # Since sanitize_email is a private method, we're using `send` to bypass and test it.
    it 'sanitizes email and removes invalid characters' do
      email = 'test!#email@domain.com'
      sanitized_email = service.send(:sanitize_email, email)
      expect(sanitized_email).to eq('testemail@domain.com')
    end
  end

  context 'when the CSV contains duplicate merchants' do
    let(:test_file_path) { Rails.root.join('spec', 'fixtures', 'duplicate_merchants.csv') }

    it 'only imports unique merchants' do
      # Assuming you have 10 merchants in your test CSV but 2 of them are duplicates.
      expect { service.perform }.to change(Merchant, :count).by(8)
    end
  end

  describe '#sanitize_email' do
    it 'removes special characters except for the allowed ones' do
      email = 'test^&*()email@domain.com'
      sanitized_email = service.send(:sanitize_email, email)
      expect(sanitized_email).to eq('testemail@domain.com')
    end

    it 'converts email to lowercase' do
      email = 'TESTEmail@DOMAIN.Com'
      sanitized_email = service.send(:sanitize_email, email)
      expect(sanitized_email).to eq('testemail@domain.com')
    end
  end
end
