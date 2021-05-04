# frozen_string_literal: true

require_relative '../../spec_helper.rb'
require_relative '../../../lib/parsers/ember_cli_tests_parser.rb'
require_relative '../../../lib/archives/file_system_archive.rb'
require 'byebug'

RSpec.describe EmberCLITestsParser do
  let(:commit_hash) { '886d619d3f' }

  before do
    working_dir = File.expand_path('../../../examples', __FILE__)
    @archive = FileSystemArchive.new(working_dir, raw_output_path)
  end

  after { @archive.destroy_tests_report }

  describe 'Parsing errors from the build' do
    let(:raw_output_path) { 'ember_cli_failed_run.txt' }
    let(:test_name) { :acceptance_review_reject_user }

    it 'Parses and stores failed tests' do
      test_failed_assertion = 'it opens reject reason modal when user is rejected and blocked'
      test_assertion_result = 'actual: false expected: true'
      name = 'Acceptance: Review: Reject user'

      parsed_output = subject.errors(@archive, commit_hash)
      failed_test = parsed_output.dig(:errors, test_name)

      expect(failed_test[:assertion]).to eq test_failed_assertion
      expect(failed_test[:result]).to eq test_assertion_result
      expect(failed_test[:test]).to eq name
      expect(failed_test[:failures]).to eq 1
      expect(failed_test[:last_seen_at]).not_to eq(nil)
    end

    it 'stores subsequent failures' do
      name = 'Acceptance: Review: Reject user'

      first_run = subject.errors(@archive, commit_hash)
      @archive.store_tests_report({ ember_cli_tests: first_run[:errors] })
      parsed_output = subject.errors(@archive, commit_hash)
      failed_test = parsed_output.dig(:errors, test_name)

      expect(failed_test[:test]).to eq name
      expect(failed_test[:failures]).to eq 2
      expect(failed_test[:last_seen_at]).not_to eq(nil)
    end

    it 'records the time of a Ember CLI test' do
      test_key = :acceptance_composer_actions_interactions
      duration = 1.091

      output = subject.slowest_tests(@archive, commit_hash)
      test_duration = output[test_key]

      expect(test_duration[:worst]).to eq duration
      expect(test_duration[:best]).to eq duration
      expect(test_duration[:average]).to eq duration
    end
  end
end
