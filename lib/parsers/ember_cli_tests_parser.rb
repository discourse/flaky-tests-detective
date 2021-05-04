# frozen_string_literal: true

require_relative 'tests_parser.rb'

class EmberCLITestsParser < TestsParser
  def attatch_to_report(report, archive, commit_hash)
    errors_report = errors(archive, commit_hash)

    report.tap do |r|
      r[:ember_cli_tests] = errors_report[:errors]

      if errors_report[:new_errors]
        r[:metadata][:new_errors] = true
      end

      r[:slowest_ember_cli_tests] = slowest_tests(archive, commit_hash)
    end
  end

  def errors(archive, commit_hash)
    state = archive.tests_report[:ember_cli_tests] || {}
    initial_s = {
      current_test_name: nil, current_assertion: '', current_result: '',
      saving_to: nil, current_test_key: nil, errors: state, new_errors: false
    }

    results = archive.raw_build_iterator.each_with_object(initial_s) do |line, s|
      stripped_line = line.strip
      next(initial_s) unless stripped_line.start_with?('not ok') || s[:current_test_key]

      if s[:current_test_key].nil?
        test_name = get_test_name(stripped_line)
        s[:current_test_name] = test_name
        s[:current_test_key] = build_test_key(test_name)
      end

      is_stack_line = stripped_line.include?('stack:')
      if is_stack_line
        s[:saving_to] = nil
      end

      if stripped_line.include?('negative:')
        error = s.dig(:errors, s[:current_test_key])

        if error
          error[:failures] += 1
          error[:appeared_on] = commit_hash unless error[:appeared_on]
          error[:last_seen] = commit_hash
          error[:assertion] = s[:current_assertion].strip if s[:current_assertion]
          error[:result] = s[:current_result].strip if s[:current_result]
        else
          error = test_template(commit_hash).merge(
            test: s[:current_test_name], assertion: s[:current_assertion].strip,
            result: s[:current_result].strip
          )
        end

        error[:last_seen_at] = Time.now.utc.to_s
        s[:new_errors] = true
        s[:errors][s[:current_test_key]] = error

        s[:current_test_key] = nil
        s[:current_module] = nil
        s[:current_result] = nil
        s[:current_assertion] = nil
      elsif stripped_line.include?('message:')
        s[:saving_to] = :current_assertion
      elsif stripped_line.include?('actual:')
        s[:saving_to] = :current_result
        s[:current_result] = stripped_line.delete('>')
      elsif stripped_line.include?('expected:')
        s[:current_result] = s[:current_result] + stripped_line.delete('>')
      elsif s[:saving_to]
        s[s[:saving_to]] = s[s[:saving_to]] + stripped_line + ' '
      end
    end

    results.slice(:new_errors, :errors)
  end

  def slowest_tests(archive, commit_hash)
    initial_s = { slowest_tests: archive.tests_report[:slowest_ember_cli_tests] || {} }

    results = archive.raw_build_iterator.each_with_object(initial_s) do |line, s|
      stripped_line = line.strip
      next(s) unless stripped_line.start_with?('ok')

      test_name = get_test_name(stripped_line)
      test_key = build_test_key(test_name)

      seconds_text = stripped_line.scan(/\d+\sms/).first
      seconds = seconds_text.delete(' ms').to_f / 1000

      test = find_test(s, test_key)
      record_time(test, test_key, seconds)

      test[:name] = test_name
      s[:slowest_tests][test_key] = test
    end

    results[:slowest_tests]
  end

  private

  def get_test_name(line)
    line.scan(/(?<=-\s)\w.+/).first
  end

  def build_test_key(raw)
    raw.delete(':').downcase.gsub(/\W/, '_').to_sym
  end
end
