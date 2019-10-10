# frozen_string_literal: true

class BuildOutputParser
  def parse_raw_from(archive)
    state = archive.tests_report
    commit_hash = parse_commit_hash(archive)
    ruby_errors = parse_ruby_errors(state[:ruby_tests], archive, commit_hash)
    js_errors = parse_js_errors(state[:js_tests], archive, commit_hash)

    {
      metadata: {
        runs: (state.dig(:metadata, :runs) + 1),
        last_commit_hash: commit_hash,
        new_errors: ruby_errors[:new_errors] || js_errors[:new_errors]
      },
      ruby_tests: ruby_errors[:errors], js_tests: js_errors[:errors]
    }
  end

  private

  def parse_commit_hash(archive)
    result = archive.raw_build_iterator.each_with_object(checked_latest: false, hash: nil) do |line, s|
      s[:checked_latest] = s[:checked_latest] || line.include?("You are in 'detached HEAD' state.")
      next(s) unless s[:checked_latest]

      commit_hash_line = line.include? 'HEAD is now at'
      if commit_hash_line
        s[:hash] = line.match(/HEAD is now at \s*(\S+)/)[1].gsub('...', '')
        break(s)
      end
    end

    result[:hash]
  end

  def parse_ruby_errors(state, archive, commit_hash)
    test_template = { failures: 1, appeared_on: commit_hash, last_seen: commit_hash }

    initial_s = {
      failure_zone: false, failure_list: false,
      errors: state, new_errors: false, test_number: 0,
      results: []
    }

    results = archive.raw_build_iterator.each_with_object(initial_s) do |line, s|
      stripped_line = line.strip

      if stripped_line.include? 'Randomized with seed'
        test_template[:seed] = stripped_line.match(/\d+/)[0]
      end

      s[:failure_zone] = s[:failure_zone] || stripped_line.include?('Failures:')
      s[:failure_list] = s[:failure_list] || stripped_line.include?('Failed examples:')
      if s[:failure_list]
        s[:test_number] = 0
        s[:failure_zone] = false
      end

      if s[:failure_zone]
        new_test = stripped_line.match?(/\d\)/)
        s[:watching_test] = s[:watching_test] || new_test

        gather_ruby_test_errors(s, new_test, stripped_line)
      elsif s[:failure_list]
        test_line = stripped_line.include? 'rspec'
        update_errors_report(s, test_line, stripped_line, test_template)
      end
    end

    results.slice(:new_errors, :errors)
  end

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
        state[:results][tn] += "#{line} \n"
      end
    end
  end

  def update_errors_report(state, is_test_line, line, test_template)
    if is_test_line
      state[:new_errors] = true

      test_data = line.gsub('rspec', '').split('#')
      test_key = test_data.first.strip
        .tr('./', '_').tr('.', '_').tr('/', '_').tr(':', '_').to_sym
      if state[:errors].key?(test_key)
        state[:errors][test_key][:failures] += 1
        state[:errors][test_key][:seed] = test_template[:seed]
        state[:errors][test_key][:last_seen] = test_template[:last_seen]
      else
        state[:errors][test_key] = test_template.merge(
          module: test_data.first.strip,
          result: state[:results][state[:test_number]],
          assertion: test_data.last,
        )
      end

      state[:test_number] += 1
    end
  end

  def parse_js_errors(state, archive, commit_hash)
    initial_s = {
      watching_test: false, current_module: nil, seed: nil,
      current_test_key: nil, errors: state, new_errors: false
    }

    results = archive.raw_build_iterator.each_with_object(initial_s) do |line, s|
      stripped_line = line.strip
      s[:seed] = stripped_line.match(/\d+/)[0] if stripped_line.include? 'Running: {"seed":'
      module_failed_line = stripped_line.include? 'Module Failed'
      test_line = stripped_line.include? 'Test Failed'
      s[:watching_test] = s[:watching_test] || module_failed_line || test_line
      next(s) unless s[:watching_test]

      assertion_description_line = stripped_line.include? 'Assertion Failed'
      assertion_line = stripped_line.include? 'Expected'

      s[:current_module] = stripped_line if module_failed_line

      if test_line
        s[:current_test_key] = build_test_key(stripped_line)
        s[:new_errors] = true

        if s[:errors].key?(s[:current_test_key])
          s[:errors][s[:current_test_key]][:failures] += 1
          s[:errors][s[:current_test_key]][:appeared_on] = commit_hash unless s[:errors][s[:current_test_key]][:appeared_on]
          s[:errors][s[:current_test_key]][:last_seen] = commit_hash
          s[:errors][s[:current_test_key]][:seed] = s[:seed]
        else
          s[:errors][s[:current_test_key]] = { module: s[:current_module], failures: 1, seed: s[:seed], appeared_on: commit_hash, last_seen: commit_hash }
        end
      end

      s[:errors][s[:current_test_key]][:assertion] = stripped_line if s[:current_test_key] && assertion_description_line
      s[:errors][s[:current_test_key]][:result] = stripped_line if s[:current_test_key] && assertion_line

      if assertion_line
        s[:watching_test] = false
        s[:current_module] = nil
      end
    end

    results.slice(:new_errors, :errors)
  end

  def build_test_key(raw)
    raw.delete(':').downcase.gsub(/\s+/, '_').to_sym
  end
end
