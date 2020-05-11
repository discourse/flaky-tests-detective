# frozen_string_literal: true

require 'date'

class MarkdownPrinter
  def print_from(report)
    title = <<~eos
      ## Tests report - #{Date.today.strftime('%m/%d/%Y')}

      >Total runs: #{report.dig(:metadata, :runs)}
      >Runs since last report: #{report.dig(:metadata, :report_runs)}
      >Last commit: #{report.dig(:metadata, :last_commit_hash)}
    eos
    slowest_ruby_tests = build_slowest_tests(:ruby, report[:slowest_ruby_tests])
    slowest_js_tests = build_slowest_tests(:js, report[:slowest_js_tests])

    if report[:ruby_tests].empty? && report[:js_tests].empty?
      <<~eos
        #{title}

        *Looks like I couldn't find any flakey tests this time :tada:*

        ---

        #{slowest_ruby_tests}
        #{slowest_js_tests}
      eos
    else
      <<~eos
        #{title}

        ### New Flakey Tests:

        ### Ruby [#{report[:ruby_tests].size} failures]

        #{build_ruby_failures(report[:ruby_tests])}
        ### JS [#{report[:js_tests].size} failures]

        #{build_js_failures(report[:js_tests])}

        ---

        #{slowest_ruby_tests}
        #{slowest_js_tests}
      eos
    end
  end

  private

  def build_ruby_failures(ruby_json)
    ordered_tests = ruby_json.values.sort_by { |r| -r[:failures] }

    ordered_tests.reduce('') do |memo, test|
      memo += <<~eos
        #### #{test[:module]}

        Total failures: #{test[:failures]}
        Failures since last report: #{test[:new_failures]}
        Last seen at: #{test[:last_seen_at]}
        #{details(test)}
      eos
    end
  end

  def build_js_failures(js_json)
    with_test_data = js_json
    with_test_data.each { |t, r| r[:test] = t }
    ordered_tests = with_test_data.values.sort_by { |r| -r[:failures] }

    ordered_tests.reduce('') do |memo, test|
      memo += <<~eos
        #### #{test[:test].to_s.gsub('_', ' ')}

        Total failures: #{test[:failures]}
        Failures since last report: #{test[:new_failures]}
        Last seen at: #{test[:last_seen_at]}
        #{test[:module]}
        #{details(test)}
      eos
    end
  end

  def build_slowest_tests(type, slowest_tests)
    ordered_tests = slowest_tests.values.sort_by { |t| -t[:average].to_i }.first(20)
    output = ordered_tests.reduce("") do |memo, test|
      memo += slow_test_row(type, test)
    end
    <<~eos
    <details>
      <summary>Slowest #{type} tests</summary>

    #{output}
    </details>
    eos
  end

  def slow_test_row(type, test)
    if type == :ruby
      <<~eos
      _#{test[:name]}_
      **Best: #{test[:best].round(2)} - Worst: #{test[:worst].round(2)} - Avg: #{test[:average].round(2)}**
      #{test[:trace]}

      eos
    else
      <<~eos
      _#{test[:output]}_
      **Best: #{test[:best].round(2)} - Worst: #{test[:worst].round(2)} - Avg: #{test[:average].round(2)}**

      eos
    end
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
