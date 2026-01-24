require_relative './redc/version'
require 'csv'

module DCDCFeedbackVoltageDividerResistorCombination
  E_series = {
    # ±20% Tolerance – Resistor values in Ω
    E6: [1.0, 1.5, 2.2, 3.3, 4.7, 6.8],
    # ±10% Tolerance – Resistor values in Ω
    E12: [1.0, 1.2, 1.5, 1.8, 2.2, 2.7, 3.3, 3.9, 4.7, 5.6, 6.8, 8.2],
    # ±5% Tolerance – Resistor values in Ω
    E24: [1.0, 1.1, 1.2, 1.3, 1.5, 1.6, 1.8, 2.0, 2.2, 2.4, 2.7, 3.0, 3.3, 3.6, 3.9, 4.3, 4.7, 5.1, 5.6, 6.2, 6.8, 7.5,
          8.2, 9.1],
    # ±2% Tolerance – Resistor values in Ω
    E48: [1.00, 1.05, 1.10, 1.15, 1.21, 1.27, 1.33, 1.40, 1.47, 1.54, 1.62, 1.69, 1.78, 1.87, 1.96, 2.05, 2.15, 2.26, 2.37, 2.49, 2.61, 2.74, 2.87,
          3.01, 3.16, 3.32, 3.48, 3.65, 3.83, 4.02, 4.22, 4.42, 4.64, 4.87, 5.11, 5.36, 5.62, 5.90, 6.19, 6.49, 6.81, 7.15, 7.50, 7.87, 8.25, 8.66, 9.09, 9.53],
    # ±1% Tolerance – Resistor values in Ω
    E96: [1.00, 1.02, 1.05, 1.07, 1.10, 1.13, 1.15, 1.18, 1.21, 1.24, 1.27, 1.30, 1.33, 1.37, 1.40, 1.43, 1.47, 1.50, 1.54, 1.58, 1.62, 1.65, 1.69,
          1.74, 1.78, 1.82, 1.87, 1.91, 1.96, 2.00, 2.05, 2.10, 2.15, 2.21, 2.26, 2.32, 2.37, 2.43, 2.49, 2.55, 2.61, 2.67, 2.74, 2.80, 2.87, 2.94, 3.01, 3.09, 3.16, 3.24, 3.32, 3.40, 3.48, 3.57, 3.65, 3.74, 3.83, 3.92, 4.02, 4.12, 4.22, 4.32, 4.42, 4.53, 4.64, 4.75, 4.87, 4.99, 5.11, 5.23, 5.36, 5.49, 5.62, 5.76, 5.90, 6.04, 6.19, 6.34, 6.49, 6.65, 6.81, 6.98, 7.15, 7.32, 7.50, 7.68, 7.87, 8.06, 8.25, 8.45, 8.66, 8.87, 9.09, 9.31, 9.53, 9.76]
  }

  Resistor_Multiple = (0..6).map { |index| 10**index }

  def self.factor(serie_code)
    E_series[:"#{serie_code.upcase}"]
  end

  def self.resistor_range(factor)
    factor.product(Resistor_Multiple).map { |a, b| BigDecimal(a.to_s) * b }
  end

  def self.calculator_resistor_bottom_value(vout, vref, resistor_top)
    resistor_top / ((vout / vref) - 1)
  end

  def self.calculator_resistor_top_value(vout, vref, resistor_bottom)
    (resistor_bottom * vref) / (vout - vref)
  end

  def self.find_closest_resistor(resistor, resistor_range)
    resistor_range.reduce do |closest, num|
      (resistor - num).abs < (resistor - closest).abs ? num : closest
    end
  end

  def self.calculator_relative_error(resistor, closest_resistor)
    (((resistor - closest_resistor).abs / resistor) * 100).round(2).to_s('F')
  end

  def self.calculator_resistor_combination_results(resistor_top_range, resistor_bottmon_range, vout, vref)
    results = []

    resistor_top_range.each do |rt|
      rb = calculator_resistor_bottom_value(vout, vref, rt)
      closest_resistor_value = find_closest_resistor(rb, resistor_bottmon_range)
      error = calculator_relative_error(rb, closest_resistor_value)

      results << {
        resistor_top: rt,
        resistor_bottom: closest_resistor_value,
        relative_error: error
      }
    end
    results
  end

  def self.format_unit(value)
    if value >= 1_000_000
      "#{(value / 1_000_000).round(2).to_s('F')}M"
    elsif value >= 1000
      "#{(value / 1000).round(2).to_s('F')}K"
    else
      value.round(2).to_s('F')
    end
  end

  def self.find_target_ohm_combination(results, target_resistor_top)
    results.sort_by { |result| (result[:resistor_top] - target_resistor_top).abs }.first
  end

  def self.format_target_resistor_combination(results, target_resistor_top)
    combination = find_target_ohm_combination(results, target_resistor_top)

    head_lines = 40

    puts '=' * head_lines
    puts format('%-20s %-10s %-10s', 'PARAMETERS', 'VALUE', 'UNIT')
    puts '-' * head_lines
    puts format('%-20s %-10s %-10s', 'resistor top', format_unit(combination[:resistor_top]), 'Ω')
    puts format('%-20s %-10s %-10s', 'resistor bottom', format_unit(combination[:resistor_bottom]), 'Ω')
    puts format('%-20s %-10s %-10s', 'relative error', combination[:relative_error], '%')
    puts '=' * head_lines
  end

  def self.format_resistor_combination_results(results)
    results = results.sort_by { |r| r[:relative_error] }

    header_lines = 60

    puts '=' * header_lines
    puts format('%-20s %-20s %-20s', 'RESISTOR_TOP(Ω)', 'RESISTOR_BOTTOM(Ω)', 'RELATIVE_ERROR(%)')
    # puts '-' * 60

    last_er = results[0][:relative_error]
    results.each do |result|
      rt = format_unit(result[:resistor_top])
      rb = format_unit(result[:resistor_bottom])
      er = result[:relative_error]

      if er != last_er
        puts '-' * header_lines
        last_er = er
      end

      puts format('%-20s %-20s %-20s', rt, rb, er)
    end
    puts '=' * header_lines
  end
end

module DCDCInductorParameters
  INDUCTOR_DATA_PATH = File.expand_path(File.join('../lib/data', 'inductor_data.csv'), __dir__)

  INDUCTOR_DATA = CSV.readlines(INDUCTOR_DATA_PATH, headers: true)

  INDUCTOR_PRIORITY = {
    '一体成型电感' => 0,
    '小型化一体成型电感' => 1,
    '立脚型一体成型电感' => 2,
    '磁封胶功率电感' => 3,
    '车规级一体成型电感' => 4,
    '车规级小型一体成型电感' => 5,
    '羰基一体成型电感' => 6,
    '小型化一体成型电感T-CORE' => 7,
    'T-CORE超大电流电感' => 8,
    '铁氧体绕线' => 9,
    '磁屏蔽罩' => 10
  }.freeze

  def self.inductor_data
    INDUCTOR_DATA
  end

  def self.standard_inductances
    @inductance ||= inductor_data['inductance'].uniq.map { |i| inductance_to_float(i) }
  end

  def self.inductance_to_float(inductance)
    rule = /[1-9]\d*\.?\d*|0\.\d*[1-9]/
    inductance.scan(rule).first.to_f
  end

  def self.inductance_to_uH(inductance)
    inductance.to_f * 10**6
  end

  def self.find_closest_standard_inductance(inductance)
    standard_inductances.reduce do |closest, num|
      (inductance - num).abs < (inductance - closest).abs ? num : closest
    end
  end

  def self.select_standard_inductor(closest_standard_inductance)
    inductor_data.select do |line|
      inductance_to_float(line['inductance']) == closest_standard_inductance
    end
  end

  def self.format_calculated_result(inductance_min_uH, standard_inductance, relative_error)
    header_lines = 45

    # puts 'CALCULATION PARAMETER:'
    puts '=' * header_lines
    puts format('%-20s %-15s %-15s', 'PARAMETERS', 'VALUE', 'UNIT')
    puts '-' * header_lines
    puts format('%-20s %-15.2f %-15s', 'inductance minimum', inductance_min_uH.round(2), 'uH')
    puts format('%-20s %-15.2f %-15s', 'inductance standard', standard_inductance.round(2), 'uH')
    puts format('%-20s %-15.2f %-15s', 'relative error', relative_error.round(2), '%')
    puts '=' * header_lines
  end

  def self.format_inductors_result(inductors)
    header_lines = 90

    # puts 'OPTIONAL MODEL LIST:'
    puts '=' * header_lines
    puts format('%-20s %-15s %-15s %-10s %-20s', 'SIZE', 'INDUCTANCE', 'DCR', 'I_SAT', 'TYPE')
    puts '-' * header_lines
    inductors = inductors.sort_by do |inductor|
      INDUCTOR_PRIORITY[inductor['type']]
    end
    inductors.each do |inductor|
      puts format('%-20s %-15s %-15s %-10s %-20s', inductor['size'], inductor['inductance'], inductor['dcr'], inductor['staturation_current'],
                  inductor['type'])
    end
    puts '=' * header_lines
  end

  def self.calculator_delta_IL(iout, vout, vin, ratio)
    ratio * iout * (vout / vin)
  end

  def self.calculator_inductance_min_uH(vin, vout, delta_IL, fsw)
    inductance_to_uH(vin * (vout - vin) / (delta_IL * fsw * vout))
  end

  def self.calculator_relative_error(inductance, closest_standard_inductance)
    (((inductance - closest_standard_inductance).abs / inductance) * 100).round(2)
  end
end

module RCDelayCalculator
  RESISTOR_E24 = [1.0, 1.1, 1.2, 1.3, 1.5, 1.6, 1.8, 2.0, 2.2, 2.4, 2.7, 3.0, 3.3, 3.6, 3.9, 4.3, 4.7, 5.1, 5.6, 6.2, 6.8, 7.5,
                  8.2, 9.1]

  CAPACITOR_E12 = [1.0, 1.2, 1.5, 1.8, 2.2, 2.7, 3.3, 3.9, 4.7, 5.6, 6.8, 8.2]

  def self.resistor_range
    resistor_multiple = (3..6).map { |index| 10**index }

    resistors = RCDelayCalculator::RESISTOR_E24.product(resistor_multiple).map { |a, b| BigDecimal(a.to_s) * b }

    resistors.select { |resistor| resistor.between?(1000, 1_000_000) }
  end

  def self.capacitor_range
    capacitor_multiple = (-10..-4).map { |index| 10**index }

    capacitors = RCDelayCalculator::CAPACITOR_E12.product(capacitor_multiple).map { |a, b| BigDecimal(a.to_s) * b }

    capacitors.select { |capacitor| capacitor.between?(10**-10, 10**-4) }
  end

  def self.time_constant(resistance, capacitance)
    resistance * capacitance
  end

  def self.delay_time(resistance, capacitance, voltage_rc, voltage_target)
    return nil if voltage_target > voltage_rc

    -time_constant(resistance, capacitance) * Math.log((voltage_rc - voltage_target) / voltage_rc)
  end

  def self.closest_value(range, value)
    range.min_by { |standard| (standard - value).abs }
  end

  # def self.closest_capacitor_value(capacitor_range, resistance, target_delay_time, voltage_rc, voltage_target)
  #   capacitance = -target_delay_time / (Math.log((voltage_rc - voltage_target) / voltage_rc) * resistance)
  #
  #   capacitor_range.min_by { |standard_capacitor| (standard_capacitor - capacitance).abs }
  # end
  #
  # def self.closest_resistance(resistor_range, capacitance, target_delay_time, voltage_rc, voltage_target)
  #   resistance = -target_delay_time / (Math.log((voltage_rc - voltage_target) / voltage_rc) * capacitance)
  #
  #   resistor_range.min_by { |standard_resistance| (standard_resistance - resistance).abs }
  # end

  def self.calculator_relative_error(target_delay_time, closest_delay_time)
    (((target_delay_time - closest_delay_time).abs / target_delay_time) * 100).round(2)
  end

  def self.calculator_rc_combination_results(mode, capacitor_range, resistor_range, target_delay_time,
                                             voltage_rc, voltage_target)
    case mode
    when :charge
      calculator_rc_combination_charge(capacitor_range, resistor_range, target_delay_time, voltage_rc, voltage_target)
    when :discharge
      calculator_rc_combination_discharge(capacitor_range, resistor_range, target_delay_time, voltage_rc,
                                          voltage_target)
    end
  end

  def self.rc_combination_charge_result(resistance, capacitance, target_delay_time, delay_time, relative_error)
    {
      resistance: resistance,
      capacitance: capacitance,
      target_delay_time: target_delay_time,
      delay_time: delay_time,
      relative_error: relative_error
    }
  end

  def self.calculator_rc_combination_charge(capacitor_range, resistor_range, target_delay_time, voltage_rc,
                                            voltage_target)
    # t = -RC * Ln(1 - (Uc / Us))
    results = []

    resistor_range.each do |resistance|
      capacitance = -target_delay_time / (Math.log(1 - (voltage_target / voltage_rc)) * resistance)
      closest_capacitance = closest_value(capacitor_range, capacitance)
      closest_delay_time = -time_constant(resistance,
                                          closest_capacitance) * Math.log((voltage_rc - voltage_target) / voltage_rc)
      error = calculator_relative_error(target_delay_time, closest_delay_time)

      results << rc_combination_charge_result(resistance, closest_capacitance, target_delay_time, closest_delay_time,
                                              error)
    end

    results
  end

  def self.calculator_rc_combination_discharge(capacitor_range, resistor_range, target_delay_time, voltage_rc,
                                               voltage_target)
    # t = -RC * Ln(Uc / Uo)
    results = []

    capacitor_range.each do |capacitance|
      resistance = -target_delay_time / (capacitance * Math.log(voltage_target / voltage_rc))
      closest_resistance = closest_value(resistor_range, resistance)
      closest_delay_time = -time_constant(closest_resistance, capacitance) * Math.log(voltage_target / voltage_rc)
      error = calculator_relative_error(target_delay_time, closest_delay_time)
      results << rc_combination_charge_result(closest_resistance, capacitance, target_delay_time, closest_delay_time,
                                              error)
    end
    results
  end

  def self.format_rc_results(rc_results, rows)
    rc_results = rc_results.sort_by { |result| result[:relative_error] }

    rows = rows <= rc_results.size ? rows : rc_results.size

    header_lines = 106

    puts '=' * header_lines
    puts format('%-20s %-20s %-25s %-20s %-20s', 'RESISTANCE(KΩ)', 'CAPACITANCE(µF)', 'TARGET_DELAY_TIME(S)',
                'DELAY_TIME(S)', 'RELATIVE_ERROR(%)')
    puts '-' * header_lines
    rows.times do |i|
      rc_result = rc_results[i]
      puts format('%-20s %-20s %-25s %-20s %-20s', (rc_result[:resistance] / 1000.0).to_s('F'), (rc_result[:capacitance] * 10**6).to_s('F'),
                  rc_result[:target_delay_time], rc_result[:delay_time].round(3).to_s('F'), rc_result[:relative_error].round(3).to_s('F'))
    end
  end
end
