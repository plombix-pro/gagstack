class ReputationThreshold < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :min_reputation, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
