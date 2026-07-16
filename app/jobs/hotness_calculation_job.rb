class HotnessCalculationJob < ApplicationJob
  queue_as :default

  def perform
    HotnessCalculator.recalculate_all!
  end
end
