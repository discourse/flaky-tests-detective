# frozen_string_literal: true

require_relative 'tests_parser.rb'

class RSpecParser < TestsParser
  def errors(state, archive, commit_hash)
    initial_s = {
      failure_zone: false, failure_list: false,
      errors: state, new_errors: false, test_number: 0,
      results: []
    }

    template = test_template(commit_hash)

    results = archive.raw_build_iterator.each_with_object(initial_s) do |line, s|
      stripped_line = strip_line(line)

      if stripped_line.include? 'Randomized with seed'
        template[:seed] = stripped_line.match(/\d+/)[0]
        if s[:failure_list] # We reached the final seed line
          s.merge!(failure_zone: false, failure_list: false, watching_test: false, results: [])
          next(s)
        end
      end

      s[:failure_zone] ||= stripped_line.include?('Failures:')
      s[:failure_list] ||= stripped_line.include?('Failed examples:')
      if s[:failure_list]
        s[:test_number] = 0
        s[:failure_zone] = false
      end

      if s[:failure_zone]
        new_test = stripped_line.match?(/\d\)/)
        s[:watching_test] ||= new_test

        gather_ruby_test_errors(s, new_test, stripped_line)
      elsif s[:failure_list]
        test_line = stripped_line.include? 'rspec'
        update_errors_report(s, test_line, stripped_line, template)
      end
    end

    results.slice(:new_errors, :errors)
  end

  def slowest_tests(state, archive, commit_hash)
    initial_s = {
      slowest_tests: state,
      watching: false,
      line_count: 0,
      last_key: nil
    }

    results = archive.raw_build_iterator.each_with_object(initial_s) do |line, s|
      stripped_line = strip_line(line)

      s[:watching] = false if s[:watching] && stripped_line == ''

      slowest_tests_start = stripped_line.include? 'Top 10 slowest examples'
      if slowest_tests_start
        s[:watching] = true
        next(s)
      end

      next(s) unless s[:watching]
      s[:line_count] += 1

      if s[:line_count] % 2 != 0
        s[:last_test_name] = stripped_line
      else
        split_line = stripped_line.split(' seconds ')

        seconds = split_line[0].strip.to_f
        trace = split_line[1].strip
        key = build_test_key(trace)

        test = find_test(s, key)

        record_time(test, key, seconds)

        test[:name] = s[:last_test_name]
        test[:trace] = trace

        s[:slowest_tests][key] = test
        s
      end
    end

    results[:slowest_tests]
  end

  private

  def gather_ruby_test_errors(state, is_new_test, line)
    if is_new_test
      state[:results] << ''
    elsif state[:watching_test]
      backtrace_end = line.include? '# ./'
      if backtrace_end
        state[:watching_test] = false
        state[:test_number] += 1
      else
        tn = state[:test_number]
        state[:results][tn] += "#{line}\n"
      end
    end
  end

  def build_test_key(raw)
    raw.strip.gsub(/\W/, '_').to_sym
  end

  def update_errors_report(state, is_test_line, line, template)
    if is_test_line
      state[:new_errors] = true

      test_data = line.gsub('rspec', '').split('#')
      test_key = build_test_key(test_data.first)

      if state[:errors].key?(test_key)
        state[:errors][test_key][:failures] += 1
        state[:errors][test_key][:seed] = template[:seed]
        state[:errors][test_key][:last_seen] = template[:last_seen]
      else
        state[:errors][test_key] = template.merge(
          module: test_data.first.strip,
          result: state[:results][state[:test_number]],
          assertion: test_data.last.strip,
        )
      end

      state[:test_number] += 1
    end
  end
end
