# frozen_string_literal: true

require_relative '../lib/expandable_event'
require_relative '../lib/erb_template'
require_relative '../lib/date_time'

# Horario
class Schedule < ApplicationRecord
  has_many :schedule_events, dependent: :destroy
  belongs_to :course

  def to_icalendar_events
    map_events_to_expandable_events
    expand_events_horizontaly
    expand_events_verticaly
    create_icalendar_events
  end

  def to_google_calendar_events; end

  private

  MODULE_LENGH = Rational(1, 18) # Time delta
  ICALENDAR_DAYS = { 0 => 'MO', 1 => 'TU', 2 => 'WE', 3 => 'TH', 4 => 'FR', 5 => 'SA', 6 => 'SU' }.freeze
  MODULES_TIME = {
    0 => { hour: 8, min: 30 },
    1 => { hour: 10, min: 0 },
    2 => { hour: 11, min: 30 },
    3 => { hour: 14, min: 0 },
    4 => { hour: 15, min: 30 },
    5 => { hour: 17, min: 0 },
    6 => { hour: 18, min: 30 },
    7 => { hour: 20, min: 0 }
  }.freeze

  def map_events_to_expandable_events
    @expandable_events = schedule_events.map do |e|
      ExpandableEvent.new(e.day, e.module, e.category, e.classroom)
    end
  end

  def expand_events_horizontaly
    @last_events_of = {}
    ScheduleEvent::DAYS.each do |day|
      @last_events_of.clear
      ScheduleEvent::MODULES.each do |mod|
        try_to_expand_event day, mod
      end
    end
  end

  def expand_events_verticaly
    @last_events_of = {}
    ScheduleEvent::MODULES.each do |mod|
      @last_events_of.clear
      ScheduleEvent::DAYS.each do |day|
        try_to_expand_event day, mod
      end
    end
  end

  def try_to_expand_event(day, mod)
    @expandable_events.each do |event|
      next unless event.in?(day, mod)

      if @last_events_of[event.category].nil?
        @last_events_of[event.category] = event
      else
        last_event = @last_events_of[event.category]
        if last_event != event && last_event.classroom == event.classroom
          @last_events_of[event.category] << event
          @expandable_events.delete event
        end
      end
    end
  end

  def create_icalendar_events
    @expandable_events.map do |event|
      # Info
      fist_day = course.term.first_day
      until_date = course.term.last_day.advance(days: 1)
      days = event.days.map { |e| ICALENDAR_DAYS[e] }.join(',')
      event_start = fist_day.to_datetime.change(MODULES_TIME[event.modules.min])
      event_start = event_start.change_wday(event.days.max_by { |d| (fist_day.day - d - 2) % 7 } + 1)
      event_end = fist_day.to_datetime.change(MODULES_TIME[event.modules.max])
      event_end = event_end.change_wday(event.days.max_by { |d| (fist_day.day - d - 2) % 7 } + 1)
      # Calendar
      icalendar_event = Icalendar::Event.new
      icalendar_event.summary = ErbTemplate.new('event/summary').render(binding)
      icalendar_event.description = ErbTemplate.new('event/description').render(binding)
      icalendar_event.location = event.classroom unless event.classroom.nil?
      icalendar_event.dtstart = event_start
      icalendar_event.dtend = event_end + MODULE_LENGH
      exdates = Holiday.all.filter_map do |holiday|
        hday = holiday.every_year ? holiday.day.change(year: course.term.first_day.year) : holiday.day
        hday = hday.to_datetime.change(hour: event_start.hour, min: event_start.min)
        course.term.first_day < hday && hday < course.term.last_day ? hday : nil
      end
      icalendar_event.exdate = exdates
      icalendar_event.rrule = "FREQ=WEEKLY;INTERVAL=1;BYDAY=#{days};UNTIL=#{until_date.strftime('%Y%m%dT000000Z')}"
      icalendar_event
    end
  end
end
