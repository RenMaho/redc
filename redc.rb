require 'csv'
require 'gli'
require 'bigdecimal'

include GLI::App

@E_series = {
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

@multiple = [10**0, 10**1, 10**2, 10**3, 10**4, 10**5, 10**6]

def resistor_range(standard)
  @factor = @E_series[:"#{standard.upcase}"]
  @factor.product(@multiple).map { |a, b| BigDecimal(a.to_s) * b }
end

# vout = vref * (1 + R1/R2)

def calc_r2(vout, vref, resistor)
  resistor / ((vout / vref) - 1)
end

def calc_r1(vout, vref, resistor)
  (resistor * vref) / (vout - vref)
end

def find_closest_resistor(resistor)
  @resistor_range.reduce do |closest, num|
    (resistor - num).abs < (resistor - closest).abs ? num : closest
  end
end

def calc_diff(resistor, closest_resistor)
  (((resistor - closest_resistor).abs / resistor) * 100).round(2).to_s('F')
end

def format_unit(resistor)
  if resistor >= 1_000_000
    "#{(resistor / 1_000_000).round(2).to_s('F')}M"
  elsif resistor >= 1000
    "#{(resistor / 1000).round(2).to_s('F')}K"
  else
    resistor.round(2).to_s('F')
  end
end

program_desc 'DCDC反馈分压电阻组合计算器'
version '1.0.1'
desc '计算DCDC反馈分压电阻组合'

command :calc do |c|
  c.desc 'Vout (V)'
  c.flag %i[vout o], required: true, type: Float

  c.desc 'Vref (V)'
  c.flag %i[vref r], required: true, type: Float

  c.desc 'Save (resistor_combination.csv'
  c.flag %i[save s], default_value: './resistor_combination.csv', required: false, type: String

  c.desc 'E-Series'
  c.flag %i[serie e], default_value: 'E24', required: false, type: String

  c.action do |_global_options, options, _args|
    vout = options[:vout]
    vref = options[:vref]
    save = options[:save]
    serie = options[:serie]

    # check options
    if vref == 0
      puts 'Error `Vref` cannot be `0`!'
      exit 1
    elsif vout == 0
      puts 'Error `Vout` cannot be `0`!'
      exit 1
    elsif !%w[E6 E12 E24 E48 E96].include?(serie.upcase)
      puts 'Error No `E-series` data!'
    end

    resistor_result = []

    @resistor_range = resistor_range(serie)
    r1_list = @factor.product([10**3, 10**4, 10**5, 10**6]).map { |a, b| BigDecimal(a.to_s) * b }

    r1_list.each do |r1|
      r2 = calc_r2(vout, vref, r1)
      closest_resistor = find_closest_resistor(r2)
      diff = calc_diff(r2, closest_resistor)

      resistor_result << { r1: r1, r2: closest_resistor, diff: diff }
    end

    resistor_result = resistor_result.sort_by { |result| result[:diff] }
    resistor_result.each do |result|
      puts "R1: #{format_unit(result[:r1])} -> R2: #{format_unit(result[:r2])} -> Diff: #{result[:diff]}%"
    end

    CSV.open(save, 'w') do |writer|
      writer << %w[R1 R2 Diff]
      resistor_result.each do |result|
        writer << result.map { |r| format_unit(r) }
      end
    end
  end
end

exit run(ARGV)
