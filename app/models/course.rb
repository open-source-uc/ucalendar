# frozen_string_literal: true

class Course < ApplicationRecord
  belongs_to :term
  belongs_to :subject
  belongs_to :academic_unit
  belongs_to :campus
  has_and_belongs_to_many :teachers
  has_one :schedule, dependent: :destroy

  enum format: %i[online in-campus mixed]

  def to_s
    display_name
  end

  def display_name
    "#{subject.code}-#{section}"
  end

  def schedule_json
    { code: display_name, modules: schedule.schedule_events.map(&:schedule_json) }
  end
end
