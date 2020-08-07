# frozen_string_literal: true

class Detective
  def investigate(build_parser, archive)
    results = build_parser.parse_raw_from(archive)
    archive.store_tests_report(results)
  end

  def report_for(report_printer, threshold, archive)
    filtered_report = archive.tests_report
    previous_report = archive.last_report_sent

    curate_report!(filtered_report, previous_report, :ruby_tests, threshold)
    curate_report!(filtered_report, previous_report, :js_tests, threshold)

    failures_since_last_report!(filtered_report, previous_report, :ruby_tests)
    failures_since_last_report!(filtered_report, previous_report, :js_tests)

    filtered_report[:metadata][:report_runs] = runs(filtered_report) - runs(previous_report)

    report_printer.print_from(filtered_report)
  end

  def report_to(client, remote_topic_id, report_printer, archive, threshold)
    report = report_for(report_printer, threshold, archive)
    client.create_post(topic_id: remote_topic_id, raw: report)
    archive.update_last_report_sent
  rescue DiscourseApi::Error => e
    e.message
  end

  private

  def runs(report)
    report.dig(:metadata, :runs).to_i
  end

  def curate_report!(report, previous_report, test_key, threshold)
    report[test_key].delete_if do |test_name, test|
      test[:failures] < threshold ||
      (!previous_report.dig(test_key).empty? &&
      report.dig(test_key, test_name, :failures) == previous_report.dig(test_key, test_name, :failures))
    end
  end

  def failures_since_last_report!(report, previous_report, test_key)
    report[test_key].each do |test_name, test|
      new_failures = report.dig(test_key, test_name, :failures) - previous_report.dig(test_key, test_name, :failures).to_i

      report[test_key][test_name][:new_failures] = new_failures
    end
  end
end
