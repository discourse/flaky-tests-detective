# frozen_string_literal: true

require 'date'

class MarkdownPrinter
  def print_from(report)
    title = <<~EOS
      ## Tests report - #{Date.today.strftime('%m/%d/%Y')}

      >Total runs: #{report.dig(:metadata, :runs)}
      >Runs since last report: #{report.dig(:metadata, :report_runs)}
      >Last commit: #{report.dig(:metadata, :last_commit_hash)}
    EOS

    <<~EOS
      #{title}

      #{flaky_tests(report)}

      #{build_js_timeouts(report[:js_timeouts])}

      ---

      #{build_slowest_tests('Ruby', report[:slowest_ruby_tests])}
      #{build_slowest_tests('JS', report[:slowest_js_tests])}
      #{build_slowest_tests('Ember CLI', report[:slowest_ember_cli_tests])}

    EOS
  end

  private

  def flaky_tests(report)
    if %i[ruby_tests js_tests ember_cli_tests].all? { |k| report[k].empty? }
      return "*Looks like I couldn't find any flaky tests this time :tada:*"
    end

    <<~EOS

    #{flaky_tests_title(report, 'Ruby', :ruby_tests)}

    #{build_failures(report[:ruby_tests])}
    #{flaky_tests_title(report, 'JS', :js_tests)}

    #{build_failures(report[:js_tests])}
    #{flaky_tests_title(report, 'Ember CLI', :ember_cli_tests)}

    #{build_failures(report[:ember_cli_tests])}
    EOS
  end

  def flaky_tests_title(report, type, key)
    if report[key].size > 0
      "### #{type} [#{report[key].size} failures]"
    else
      "### #{type} :white_check_mark:"
    end
  end

  def build_failures(json)
    ordered_tests = json.values.sort_by { |r| -r[:failures] }

    ordered_tests.reduce('') do |memo, test|
      memo += <<~eos
        #### #{test[:test] || test[:module]}

        Total failures: #{test[:failures]}
        Failures since last report: #{test[:new_failures]}
        Last seen at: #{test[:last_seen_at]}
        #{details(test)}
      eos
    end
  end

  def build_js_timeouts(js_json)
    return nil if js_json.empty?

    timeouts = js_json.reduce('') do |memo, timeout|
      memo += <<~eos
        - Commit: #{timeout[0]}  Seed: #{timeout[1]}
      eos
    end

    <<~EOS
      ### JS Timeouts

      #{timeouts}
    EOS
  end

  def build_slowest_tests(type, slowest_tests)
    ordered_tests = slowest_tests.values
      .select { |t| t[:occurances].to_i >= 10 }
      .sort_by { |t| -t[:average].to_i }
      .first(20)

    output = ordered_tests.reduce("") do |memo, test|
      memo += slow_test_row(test)
    end

    <<~eos
    <details>
      <summary>Slowest #{type} tests</summary>

    #{output}
    </details>
    eos
  end

  def slow_test_row(test)
    name = test[:name] || test[:output]
    <<~EOS
    _#{name}_
    **Best: #{test[:best].round(2)} - Worst: #{test[:worst].round(2)} - Avg: #{test[:average].round(2)}**
    #{test[:trace]}
    EOS
  end

  def details(test)
    <<~eos
    <details>
      <summary>Show details</summary>

    - **Seed:** #{test[:seed]}
    - **First seen:** #{test[:appeared_on]}
    - **Last seen:** #{test[:last_seen]}
    - **Assertion:** #{test[:assertion]}
    - **Result:**
    ```
    #{test[:result]}
    ```
    </details>
    eos
  end
end
