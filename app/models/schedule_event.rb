# frozen_string_literal: true

class ScheduleEvent < ApplicationRecord
  enum category: %i[class assis lab workshop field practice tesis other]
  belongs_to :schedule

  DAYS = (0..5).to_a.freeze
  MODULES = (0..8).to_a.freeze

  def schedule_min_json
    { c: category, d: day, m: self.module }
  end
end
