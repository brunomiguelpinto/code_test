# spec/factories/orders.rb

FactoryBot.define do
  factory :order do
    amount { 1000 }
    merchant
  end
end
