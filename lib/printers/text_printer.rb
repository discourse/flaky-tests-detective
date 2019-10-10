# frozen_string_literal: false

class TextPrinter
  def print_from(raw_report)
    plain_report = headers [], raw_report[:metadata]
    plain_report << ruby_tests(raw_report[:ruby_tests])
    plain_report << js_tests(raw_report[:js_tests])
  end

  private

  def headers(output, metadata)
    output << 'Flaky tests report'
    output << "Runs: #{metadata[:runs]} Last commit: #{metadata[:last_commit_hash]}"
    output << draw_line
  end

  def ruby_tests(tests_report)
    ordered_tests = tests_report.values.sort_by { |r| -r[:failures] }

    test_output = ['Ruby tests', '----------------------------------', '']

    ordered_tests.reduce(test_output) do |result, test|
      result << "Test: #{test[:module]}"
      result << "Author: #{blame(test[:module])}"
      result << "Failures: #{test[:failures]}"
      result << "Appeared on: #{test[:appeared_on]}- Last seen: #{test[:last_seen]}"
      result << "Seed: #{test[:seed]}"
      result << "Reason: #{test[:assertion]}"
      result << "Assertion: #{test[:result]}"
      result << draw_line
    end << ''
  end

  def blame(test_path)
    file, line = test_path.split(':')

    `git blame -L #{line},#{line} -- #{file} | cat`
  end

  def js_tests(tests_report)
    with_test_data = tests_report
    tests_report.each { |t, r| r[:test] = t }
    ordered_tests = with_test_data.values.sort_by { |r| -r[:failures] }

    test_output = ['JS tests', '----------------------------------', '']

    ordered_tests.reduce(test_output) do |result, test|
      result << "Test: #{test[:test]}"
      result << test[:module] if test[:module]
      result << "Failures: #{test[:failures]}"
      result << "Appeared on: #{test[:appeared_on]}- Last seen: #{test[:last_seen]}"
      result << "Seed: #{test[:seed]}"
      result << "Assertion: #{test[:result]}"
      result << draw_line
    end
  end

  def draw_line
    '-------------------------------'
  end
end
