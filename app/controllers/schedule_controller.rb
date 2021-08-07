# frozen_string_literal: true

require 'set'
require_relative '../lib/buscacursos_scraper'

# Controlador para obtener el horario de cursos
class ScheduleController < ApplicationController
  before_action :find_term, only: :show
  before_action :find_courses, only: :show
  before_action :set_flyyer, only: :show

  def show
    respond_to do |format|
      format.html
      # XML (AJAX)
      if @term.nil?
        format.xml do
          response = "<h1>#{t('period_not_found', year: params[:year], period: params[:period])}</h1>"
          render inline: response, status: :not_found
        end
      else
        format.xml { render partial: 'schedule_table_and_links.html' }
      end
      # ICS
      if @courses.empty?
        format.ics { head :no_content }
      else
        format.ics { send_data ics_format, type: 'text/calendar' }
      end
    end
  end

  def show_short # rubocop:disable Metrics/AbcSize
    year = params[:year] || DateTime.now.advance(months: 1).year
    period = params[:period] || (DateTime.now.advance(months: 1).month / 12 + 1)
    ncr = params[:nrc].is_a?(Array) ? params[:nrc] : params[:nrc]&.split(',')
    cs = params[:cs].is_a?(Array) ? params[:cs] : params[:cs]&.split(',')
    redirect_to schedule_path(year, period, nrc: ncr, cs: cs, format: params[:format])
  end

  private

  def find_term
    @term = Term.find_by(year: params[:year], period: params[:period])
  end

  def find_courses
    @courses = Set[] # Evita obtener resultados repetidos
    params[:cs] = params[:cs]&.map(&:upcase)

    return if @term.nil?

    @courses += find_courses_by_nrc unless params[:nrc].nil?
    @courses += find_courses_by_course_and_section unless params[:cs].nil?
  end

  def find_courses_by_nrc
    params[:nrc].filter_map do |n|
      results = @term.courses.find_by(nrc: n)
      if results.nil?
        obtain_missing_course({ nrc: n })
        @term.courses.find_by(nrc: n)
      else
        results
      end
    end
  end

  def find_courses_by_course_and_section
    params[:cs].map { |c| c.split('-') }.filter_map do |course_section|
      next unless course_section.length == 2

      subject_code, section = course_section
      results = @term.courses.find_by(section: section, subject: Subject.find_by(code: subject_code))
      if results.nil?
        obtain_missing_course({ code: subject_code })
        results = @term.courses.find_by(section: section, subject: Subject.find_by(code: subject_code))
      end
      results
    end
  end

  def ics_format
    calendar = Icalendar::Calendar.new
    @courses.each do |course|
      course.schedule.to_icalendar_events.each do |event|
        calendar.add_event(event)
      end
    end
    calendar.prodid = 'benjavicente/ucalendar'
    calendar.append_custom_property('X-WR-CALNAME', I18n.t('schedule'))
    calendar.append_custom_property('X-WR-TIMEZONE', 'America/Santiago')
    calendar.to_ical
  end

  # TODO: adapter?

  MAP_DAYS = { 'L' => 0, 'M' => 1, 'W' => 2, 'J' => 3, 'V' => 4, 'S' => 5, 'D' => 6 }.freeze
  MAP_CATEGORY = Hash.new(:other).update(
    {
      'CLAS' => :class,
      'AYU' => :assis,
      'LAB' => :lab,
      'TAL' => :workshop,
      'TER' => :field,
      'PRA' => :practice,
      'TES' => :tesis
    }
  ).freeze

  def obtain_missing_course(**hash)
    results = BuscacursosScraper.instance.get_courses(year: @term.year, period: @term.period_int, **hash)
    results.each do |r|
      create_course_from_result(r) unless @term.courses.exists?(nrc: r[:nrc])
    end
  end

  def create_course_from_result(result)
    # Se crean los componentes si no existen
    teachers = result[:teachers].map do |t_name|
      Teacher.find_or_create_by(name: t_name)
    end
    # Se crea al curso
    course = @term.courses.create do |c|
      c.nrc = result[:nrc]
      c.section = result[:sec]
      c.campus = Campus.find_or_create_by(name: result[:campus])
      c.academic_unit = AcademicUnit.find_or_create_by(name: result[:academic_unit])
      c.subject = Subject.find_or_create_by(code: result[:code], name: result[:name])
      c.teachers = teachers
    end

    begin
      # Se crea el horario
      schedule = Schedule.find_or_create_by(course: course)
      result[:schedule].map do |event|
        day, mod = event[:module].chars
        schedule.schedule_events.create do |e|
          e.day = MAP_DAYS[day]
          e.module = mod.to_i - 1
          e.classroom = event[:classroom]
          e.category = MAP_CATEGORY[event[:type]]
        end
      end
    rescue StandardError => e
      # Evita que un curso se mantenga sin horario completo
      course&.destroy!
      raise e
    end
    # TODO: Se busncan las pruebas
    # BuscacursosScraper.instance.get_exams(courses.map(&:to_s), @term.period, @term.year)
  end

  def set_flyyer
    flyyer = Flyyer::Flyyer.create do |f|
      f.project = 'ucalendar'
      f.path = request.path
      f.variables = { courses: @courses.map(&:schedule_json) }
    end
    image_src = flyyer.href.html_safe
    social_image = { _: image_src }
    set_meta_tags image_src: image_src, og: { image: social_image }, twitter: { image: social_image }
  end
end
