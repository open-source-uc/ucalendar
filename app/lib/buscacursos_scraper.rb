# frozen_string_literal: true

# Implementación en Ruby del Scraper

require 'http'
require 'nokogiri'
require 'date'
require 'cgi'
require 'singleton'

# TODO: usar metodos de clase o modulos

# Scraper de BuscaCursos
class BuscacursosScraper
  include Singleton

  # Lista de hashs de cursos,
  # obtenidos de buscacursos.uc.cl
  # Los parámetros son:
  #  - year   (necesario)
  #  - period (necesario)
  #  - code
  #  - nrc
  #  - name
  #  - category
  #  - area
  #  - format
  #  - teacher
  #  - campus
  #  - academic_unit
  def get_courses(**parameters)
    soup = get_soup(get_courses_address(**parameters))
    results = soup.css('table tr[class*="resultados"]')
    results.map { |row| clean_courses_row(row) }
  end

  # Lista de hashs de las pruebas
  # Requiere una lista de cursos con sus secciones [EJP123-4], el semestre y el año
  def get_exams(courses_sections, semester, year)
    url = "#{ENV['BC_HOST']}/MiCalendarioDePruebas.ics.php"
    response = HTTP.cookies("cursosuc-#{year}-#{semester}" => courses_sections.join('%2C')).get(url)

    return [] if response.content_type != 'text/ics'

    # ! Se usa expresiones regulares ya que el formato del
    # ! archivo retornado por BuscaCursos no es válido como ics
    response.to_s.scan(/SUMMARY:(?<name>[^\n]*)\nDTSTART;VALUE=DATE:(?<date>[^\n]*)/).map do |name, date|
      { name: name.force_encoding('utf-8'), date: Date.strptime(date, '%d%b%y') }
    end
  end

  # Obtiene los detalles de las vacantes de un curso
  def get_vacancy(course_nrc, semester, year)
    url = "#{ENV['BC_HOST']}/informacionVacReserva.ajax.php?nrc=#{course_nrc}&termcode=#{year}-#{semester}"
    soup = get_soup(url)
    results = soup.css('table tr[class*="resultados"]')
    results[1...-1].map do |row|
      VAC_COLS_NAMES.zip(row.elements).transform_values do |name, elem|
        [name, clean_value(elem.content.strip)]
      end
    end
  end

  # Similar a get_exams, pero obtiene el url de la página con los cursos
  def get_schedule_url(courses_sections, period, year)
    "#{ENV['BC_HOST']}/?semestre=#{year}-#{period}&cursos=#{courses_sections.join(',')}"
  end

  private

  COLS_NAMES = %i[
    nrc code withdrawal? english? sec require_special_approval? fg_area format category
    name teachers campus credits total_vacancy available_vacancy reserved schedule
  ].freeze

  MODULE_COLS_NAMES = %i[module type classroom].freeze

  VAC_COLS_NAMES = %i[
    school level program concentration cohort
    admision_period offered occupied available
  ].freeze

  # Obtiene la Sopa (HTMl parseado)
  def get_soup(url)
    Nokogiri::HTML HTTP.get(url).to_s
  end

  # Obtiene el url de la búsqueda
  def get_courses_address(**parameters)
    parameters.default = ''
    parameters.transform_values! { |v| v.is_a?(String) ? CGI.escape(v) : v }
    format(
      "#{ENV['BC_HOST']}/?cxml_semestre=%<year>s-%<period>s"\
      '&cxml_sigla=%<code>s&cxml_nrc=%<nrc>s&cxml_nombre=%<name>s'\
      '&cxml_categoria=%<category>s&cxml_area_fg=%<area>s'\
      '&cxml_formato_cur=%<format>s&cxml_profesor=%<teacher>s'\
      '&cxml_campus=%<campus>s&cxml_unidad_academica=%<academic_unit>s',
      parameters
    )
  end

  # Limpia cada fila de los resultados
  def clean_courses_row(row)
    row_content = []
    # Se obtiene la unidad académica
    acd = row
    acd = acd.previous while acd.key?('style') || acd.key?('class') || acd.content.strip.empty?
    row_content << [:academic_unit, acd.content.strip]
    # Se obtiene cada elemento de la fila
    COLS_NAMES.zip(row.elements).each do |name, elem|
      row_content << [name, clean_courses_row_element(elem, name)]
    end
    row_content.to_h
  end

  # Limpia cada elemento de la fila
  def clean_courses_row_element(elem, name)
    if name == :teachers
      elem.content.split(',').map(&:strip)
    elsif elem.elements.first&.name == 'table'
      clear_courses_modules(elem.elements.first)
    else
      clean_value(elem.content.strip)
    end
  end

  # Simplificación de valores
  def clean_value(value)
    if %w[NO SI].include? value
      value == 'si'
    elsif Integer(value, exception: false)
      value.to_i
    elsif value.empty?
      nil
    else
      value
    end
  end

  # Limpia el horario de cada resultado
  def clear_courses_modules(module_table)
    modules_items = []
    module_table.elements.each do |mod_row|
      mod_data, type, classroom = mod_row.elements.map(&:content).map(&:strip)
      classroom = /sin sala|por asignar/i.match?(classroom) ? nil : classroom
      module_product(mod_data).each do |m|
        modules_items << MODULE_COLS_NAMES.zip([m, type, classroom]).to_h
      end
    end
    modules_items
  end

  # Producto entre los módulos
  def module_product(module_string)
    day, hr = module_string.split(':')
    return [] if day.nil? || hr.nil?

    day.split('-').product(hr.split(',')).map(&:join)
  end
end
