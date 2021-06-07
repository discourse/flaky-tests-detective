# frozen_string_literal: true

require_relative '../spec_helper.rb'
require_relative '../../lib/detective.rb'
require_relative '../../lib/printers/json_printer.rb'
require_relative '../../lib/archives/memory_archive.rb'
require 'discourse_api'

RSpec.describe Detective do
  let(:raw_report) do
    {
      metadata: { runs: 1 },
      ruby_tests: { test_ruby_a: { failures: 1, module: '/spec/test_ruby_a.rb' }, test_ruby_b: { failures: 2, module: '/spec/test_ruby_b.rb' } },
      js_tests: { test_js_a: { failures: 6 }, test_js_b: { failures: 3 } },
      ember_cli_tests: { test_cli_a: { failures: 6 }, test_cli_b: { failures: 3 } }
    }
  end

  let(:archive) { MemoryArchive.new(raw_report, metadata: { runs: 0 }, ruby_tests: {}, js_tests: {}, ember_cli_tests: {}) }

  describe '#report_for' do
    it 'filters tests with less than one failures' do
      threshold = 1

      report = build_report(threshold, archive)

      expect(selected_tests(report)).to contain_exactly(:test_ruby_a, :test_ruby_b, :test_js_a, :test_js_b)
    end

    it 'filters tests with less than two failures' do
      threshold = 2

      report = build_report(threshold, archive)

      expect(selected_tests(report)).to contain_exactly(:test_ruby_b, :test_js_a, :test_js_b)
    end

    it 'filters tests with less than five failures' do
      threshold = 5

      report = build_report(threshold, archive)

      expect(selected_tests(report)).to contain_exactly(:test_js_a)
    end

    describe 'When we are building a subsequent report' do
      let(:previous_report) do
        {
          metadata: { runs: 1 },
          ruby_tests: { test_ruby_a: { failures: 1, module: '/spec/test_ruby_a.rb'  }, test_ruby_b: { failures: 1, module: '/spec/test_ruby_b.rb' } },
          js_tests: { test_js_a: { failures: 6 }, test_js_b: { failures: 2 } },
          ember_cli_tests: { test_cli_a: { failures: 1 }, test_cli_b: { failures: 2 } }
        }
      end

      let(:archive) { MemoryArchive.new(raw_report, previous_report) }

      it 'returns the test that changed since the last report' do
        threshold = 2

        report = build_report(threshold, archive)

        expect(selected_tests(report)).to contain_exactly(:test_ruby_b, :test_js_b)
      end

      it 'takes the threshold into account' do
        threshold = 5

        report = build_report(threshold, archive)

        expect(selected_tests(report)).to be_empty
      end
    end

    def build_report(threshold, archive)
      subject.report_for(JSONPrinter.new, threshold, archive)
    end

    def selected_tests(report)
      report[:ruby_tests].keys + report[:js_tests].keys
    end
  end

  describe '#report_to' do
    it 'updates the last report sent after posting through the client' do
      remote_topic_id = 1
      threshold = 1
      subject.report_to(DummyClient.new, remote_topic_id, JSONPrinter.new, archive, threshold)

      expect(archive.last_report_sent).to eq raw_report
    end

    it "doesn't updates the last report sent when posting fails" do
      remote_topic_id = 1
      threshold = 1
      subject.report_to(DummyClient.new(raise_exception: true), remote_topic_id, JSONPrinter.new, archive, threshold)

      expect(archive.last_report_sent).not_to eq raw_report
    end

    class DummyClient
      def initialize(raise_exception: false)
        @raise_exception = raise_exception
      end

      def create_post(args)
        raise ::DiscourseApi::Error if @raise_exception
      end
    end
  end
end
