# frozen_string_literal: true

# This is the Order model representing individual orders made through the system.
class Order < ApplicationRecord
  # Each order belongs to a merchant, establishing a many-to-one relationship.
  belongs_to :merchant
end
