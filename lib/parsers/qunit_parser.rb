# frozen_string_literal: true

require_relative 'tests_parser.rb'

class QUnitParser < TestsParser
  def errors(state, archive, commit_hash)
    initial_s = {
      watching_test: false, current_module: nil, current_assertion: nil,
      current_test_key: nil, errors: state, new_errors: false
    }

    template = test_template(commit_hash)
    failed_modules = []

    results = archive.raw_build_iterator.each_with_object(initial_s) do |line, s|
      stripped_line = strip_line(line)
      template[:seed] = stripped_line.match(/(?<="seed":")[0-9]+/)[0] if stripped_line.include? '"seed":"'

      failed_modules << stripped_line if stripped_line.include? '[✘]'

      test_line = stripped_line.include? 'Test Failed'
      s[:watching_test] ||= test_line
      next(s) unless s[:watching_test]

      s[:current_test_key] = build_test_key(stripped_line) if test_line

      assertion_description = stripped_line.include? 'Assertion Failed'
      s[:current_assertion] = stripped_line if s[:current_test_key] && assertion_description

      assertion_line = stripped_line.include?('Expected:') && stripped_line.include?('Actual:')

      if assertion_line && s[:current_test_key]
        error = s[:errors][s[:current_test_key]]
        module_match = s[:current_test_key].to_s.gsub('_', ' ').gsub('test failed ', '')
        test_module = (failed_modules.detect { |m| m.include? module_match } || '').gsub(/(↪|\[✘\])/, '').strip

        if error
          error[:failures] += 1
          error[:appeared_on] = commit_hash unless error[:appeared_on]
          error[:last_seen] = commit_hash
          error[:seed] = template[:seed] if template[:seed]
          error[:assertion] = s[:current_assertion] if s[:current_assertion]
          error[:module] = test_module if test_module
        else
          error = template.merge(module: test_module, assertion: s[:current_assertion])
        end

        error[:result] = stripped_line
        error[:last_seen_at] = Time.now.utc.to_s
        s[:errors][s[:current_test_key]] = error

        s[:new_errors] = true
        s[:current_test_key] = nil
        s[:watching_test] = false
        s[:current_module] = nil
      end
    end

    results.slice(:new_errors, :errors)
  end

  def slowest_tests(state, archive, commit_hash)
    initial_s = {
      slowest_tests: state,
      watching: false,
      skip_next: false
    }

    results = archive.raw_build_iterator.each_with_object(initial_s) do |line, s|
      stripped_line = strip_line(line)

      slowest_tests_start = stripped_line.include? 'Slowest tests'
      if slowest_tests_start
        s[:skip_next] = true
        next(s)
      end

      if s[:skip_next]
        s[:watching] = true
        s[:skip_next] = false
        next(s)
      end

      next(s) unless s[:watching]
      return s[:slowest_tests] if stripped_line.include? 'Time:'

      seconds_text = stripped_line.match(/\d+ms/)[0]
      seconds = seconds_text.delete('ms').to_f / 1000
      name = stripped_line.gsub(": #{seconds_text}", '')
      key = build_test_key(name)

      test = find_test(s, key)

      record_time(test, key, seconds)

      test[:output] = name
      s[:slowest_tests][key] = test
    end

    results.slice(:slowest_tests)
  end

  private

  def build_test_key(raw)
    raw.delete(':').downcase.gsub(/\W/, '_').to_sym
  end
end
