# frozen_string_literal: true

class CreateMerchants < ActiveRecord::Migration[7.0]
  def change
    create_table :merchants do |t|
      t.string :reference, null: false, unique: true
      t.string :email, null: false, unique: true
      t.date :live_on
      t.string :disbursement_frequency
      t.integer :minimum_monthly_fee_cents
      t.string :currency

      t.timestamps
    end
    add_index :merchants, :reference, unique: true
    add_index :merchants, :email, unique: true
  end
end
