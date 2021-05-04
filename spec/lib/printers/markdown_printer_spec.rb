# frozen_string_literal: true

require_relative '../../spec_helper.rb'
require_relative '../../../lib/printers/markdown_printer.rb'
require 'json'
require 'fileutils'
require 'date'

RSpec.describe MarkdownPrinter do
  let(:raw_json_path) { File.expand_path('../../examples/test_reports/build_report.json', __dir__) }
  let(:json_report) { JSON.parse(File.read(raw_json_path), symbolize_names: true) }

  it 'includes the title' do
    title = "## Tests report - #{Date.today.strftime('%m/%d/%Y')}"

    report = subject.print_from(json_report)

    expect(report).to include(title)
  end

  it 'includes the total runs amount' do
    runs_count = json_report.dig(:metadata, :runs)

    report = subject.print_from(json_report)

    expect(report).to include(">Total runs: #{runs_count}")
  end

  it 'includes the last commit hash' do
    last_commit = json_report.dig(:metadata, :last_commit_hash)

    report = subject.print_from(json_report)

    expect(report).to include(">Last commit: #{last_commit}")
  end

  context 'When report is empty' do
    let(:json_report) { { ruby_tests: {}, js_tests: {} , slowest_ruby_tests: {}, slowest_js_tests: {}, slowest_ember_cli_tests: {} } }

    it 'includes a message saying there is no new flakey tests' do
      body = "*Looks like I couldn't find any flaky tests this time :tada:*"

      report = subject.print_from(json_report)

      expect(report).to include(body)
    end
  end
end
