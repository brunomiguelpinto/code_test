# frozen_string_literal: true

class CreateDisbursements < ActiveRecord::Migration[7.0]
  def change
    create_table :disbursements do |t|
      t.references :merchant, null: false, foreign_key: true
      t.string :reference, null: false, unique: true
      t.integer :amount_cents, null: false, default: 0
      t.integer :fee_cents, null: false, default: 0
      t.integer :monthly_fee_cents, null: false, default: 0
      t.date :disbursed_on, null: false

      t.timestamps
    end
    add_index :disbursements, %i[merchant_id disbursed_on], unique: true
  end
end
