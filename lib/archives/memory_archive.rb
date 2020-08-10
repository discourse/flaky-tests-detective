# frozen_string_literal: true

class MemoryArchive
  def initialize(report, last_report_sent)
    @tests_report = report
    @last_report_sent = last_report_sent
  end

  attr_reader :tests_report, :last_report_sent

  def store_tests_report(report)
    @tests_report = report
  end

  def update_last_report_sent
    @last_report_sent = @tests_report
  end

  def clean_report
    { metadata: { runs: 0, last_commit_hash: nil }, ruby_tests: {}, js_tests: {}, js_timeouts: [] }
  end
end
