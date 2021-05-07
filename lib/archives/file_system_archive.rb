# frozen_string_literal: true

require 'json'
require 'fileutils'

class FileSystemArchive
  def initialize(working_dir, last_build_file_name)
    @working_dir = working_dir
    @last_build_file_name = last_build_file_name
  end

  def tests_report
    @test_report ||= find_report(tests_report_path)
  end

  def store_tests_report(report)
    File.write(tests_report_path, report.to_json)
    @test_report = report
  end

  def destroy_tests_report
    FileUtils.rm(tests_report_path) if File.exist?(tests_report_path)
  end

  def last_report_sent
    @last_report_sent ||= find_report(last_report_path)
  end

  def update_last_report_sent
    current_report = tests_report
    File.write(last_report_path, current_report.to_json)

    # Clear JS timeouts and tests duration so they don't impact next report.
    current_report[:js_timeouts] = []
    current_report[:slowest_ruby_tests] = {}
    current_report[:slowest_js_tests] =  {}
    store_tests_report(current_report)

    @last_report_sent = tests_report
  end

  def clean_report
    {
      metadata: { runs: 0, last_commit_hash: nil },
      ruby_tests: {},
      js_tests: {},
      ember_cli_tests: {},
      js_timeouts: [],
      slowest_ruby_tests: {},
      slowest_js_tests: {},
      slowest_ember_cli_tests: {},
    }
  end

  def raw_build_iterator
    File.foreach("#{@working_dir}/#{@last_build_file_name}")
  end

  private

  def last_report_path
    "#{@working_dir}/last_report_sent.json"
  end

  def tests_report_path
    "#{@working_dir}/build_report.json"
  end

  def find_report(report_path)
    return clean_report unless File.exist?(report_path)

    raw_report = File.read(report_path)

    JSON.parse(raw_report, symbolize_names: true)
  end
end
