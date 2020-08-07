# frozen_string_literal: true

require_relative '../../spec_helper.rb'
require_relative '../../../lib/parsers/build_parser.rb'
require_relative '../../../lib/archives/file_system_archive.rb'

RSpec.describe BuildParser do
  let(:clean_state) do
    { metadata: { runs: 0, last_commit_hash: nil }, ruby_tests: {}, js_tests: {} }
  end

  before do
    working_dir = File.expand_path('../../../examples', __FILE__)
    @archive = FileSystemArchive.new(working_dir, raw_output_path)
  end

  after { @archive.destroy_tests_report }

  describe 'Build metadata' do
    let(:raw_output_path) { 'succesful_run.txt' }

    it 'Increments the amount of runs' do
      results = subject.parse_raw_from(@archive)

      expect(results.dig(:metadata, :runs)).to eq clean_state.dig(:metadata, :runs) + 1
      expect(results.dig(:metadata, :new_errors)).to eq false
    end

    it 'Returns the last stable commit hash' do
      expected_commit_hash = '9a81cb9'

      results = subject.parse_raw_from(@archive)

      expect(results.dig(:metadata, :last_commit_hash)).to eq expected_commit_hash
    end
  end

  describe 'Parsing a succesful build' do
    let(:raw_output_path) { 'succesful_run.txt' }

    it 'Returns no errors' do
      failed_tests = subject.parse_raw_from(@archive)

      expect(failed_tests[:ruby_tests]).to be_empty
      expect(failed_tests[:js_tests]).to be_empty
    end
  end

  describe 'Parsing a build with JS errors' do
    let(:raw_output_path) { 'qunit_failed_run.txt' }

    context 'Discourse core tests' do
      let(:test_name) { :test_failed_display_and_hide }

      it 'Parses and stores failed tests' do
        test_failed_assertion = 'Assertion Failed: "abort"'
        test_assertion_result = 'Expected: true, Actual: false'
        test_module = 'Acceptance: Discourse Tooltips::display and hide'

        parsed_output = subject.parse_raw_from(@archive)
        failed_test = parsed_output.dig(:js_tests, test_name)

        expect(failed_test[:assertion]).to eq test_failed_assertion
        expect(failed_test[:result]).to eq test_assertion_result
        expect(failed_test[:module]).to eq test_module
        expect(failed_test[:failures]).to eq 1
        expect(failed_test[:last_seen_at]).not_to eq(nil)
      end

      it 'Updates initial state and returns a new state when the failures counter is incremented' do
        first_run_state = subject.parse_raw_from(@archive)
        @archive.store_tests_report(first_run_state)
        second_run = subject.parse_raw_from(@archive)
        failed_test = second_run.dig(:js_tests, test_name)

        expect(failed_test[:failures]).to eq 2
        expect(second_run.dig(:metadata, :new_errors)).to eq true
      end

      it 'Stores the seed' do
        expected_seed = '244504690341935418402669109164211076907'

        parsed_output = subject.parse_raw_from(@archive)
        failed_test = parsed_output.dig(:js_tests, test_name)

        expect(failed_test[:seed]).to eq expected_seed
      end
    end
  end

  describe 'Parsing a build with RSpec errors' do
    let(:raw_output_path) { 'rspec_failed_run.txt' }

    context 'Discourse core tests' do
      let(:test_name) { :__spec_requests_finish_installation_controller_spec_rb_11 }

      it 'Parses and stores failed tests' do
        test_failed_assertion = "index has_login_hint is false doesn't allow access"
        test_assertion_result = <<~EOS
          Failure/Error: expect(response).not_to be_forbidden
          expected `#<ActionDispatch::TestResponse:0x000055a703336698 @mon_mutex=#<Thread::Mutex:0x000055a703336620>, @mo..., @method=nil, @request_method=nil, @remote_ip=nil, @original_fullpath=nil, @fullpath=nil, @ip=nil>>.forbidden?` to return false, got true
        EOS
        test_module = './spec/requests/finish_installation_controller_spec.rb:11'

        parsed_output = subject.parse_raw_from(@archive)
        failed_test = parsed_output.dig(:ruby_tests, test_name)

        expect(failed_test[:assertion]).to eq test_failed_assertion
        expect(failed_test[:result]).to eq test_assertion_result
        expect(failed_test[:module]).to eq test_module
        expect(failed_test[:failures]).to eq 1
        expect(failed_test[:last_seen_at]).not_to eq(nil)
      end

      it 'Updates initial state and returns a new state when the failures counter is incremented' do
        first_run_state = subject.parse_raw_from(@archive)
        @archive.store_tests_report(first_run_state)
        second_run = subject.parse_raw_from(@archive)
        failed_test = second_run.dig(:ruby_tests, test_name)

        expect(failed_test[:failures]).to eq 2
        expect(second_run.dig(:metadata, :new_errors)).to eq true
      end

      it 'Stores the seed' do
        expected_seed = '21827'

        parsed_output = subject.parse_raw_from(@archive)
        failed_test = parsed_output.dig(:ruby_tests, test_name)

        expect(failed_test[:seed]).to eq expected_seed
      end
    end

    context 'Discourse plugin tests' do
      let(:test_name) { :__plugins_discourse_calendar_spec_jobs_ensure_expired_event_destruction_spec_rb_66 }

      it 'Parses and stores failed tests' do
        test_failed_assertion = "DiscourseCalendar::EnsuredExpiredEventDestruction wont destroy recurring events"
        test_assertion_result = <<~EOS
          Failure/Error:
          expect(@op.calendar_details[@post.post_number.to_s]).to eq([
          "Rome  to", "2018-06-05T10:20:00Z", "2018-06-06T11:20:00Z", @post.user.username_lower, "1.weeks"
          ])

          expected: ["Rome  to", "2018-06-05T10:20:00Z", "2018-06-06T11:20:00Z", "bruce284", "1.weeks"]
          got: ["Rome  to", "2018-06-05T10:20:00Z", "2018-06-06T11:20:00Z", "bruce284", "1.weeks", "/t/-/111/3"]

          (compared using ==)
        EOS
        test_module = './plugins/discourse-calendar/spec/jobs/ensure_expired_event_destruction_spec.rb:66'

        parsed_output = subject.parse_raw_from(@archive)
        failed_test = parsed_output.dig(:ruby_tests, test_name)

        expect(failed_test[:assertion]).to eq test_failed_assertion
        expect(failed_test[:result]).to eq test_assertion_result
        expect(failed_test[:module]).to eq test_module
        expect(failed_test[:failures]).to eq 1
        expect(failed_test[:last_seen_at]).not_to eq(nil)
      end

      it 'Stores the seed' do
        expected_seed = '47979'

        parsed_output = subject.parse_raw_from(@archive)
        failed_test = parsed_output.dig(:ruby_tests, test_name)

        expect(failed_test[:seed]).to eq expected_seed
      end
    end
  end

  describe 'Parsing slowest RSpec test duration' do
    let(:raw_output_path) { 'succesful_run.txt' }

    it 'records the time of a RSpec slow test' do
      test_key = :__spec_requests_admin_themes_controller_spec_rb_104
      duration = 40.13

      output = subject.parse_raw_from(@archive)
      test_duration = output.dig(:slowest_ruby_tests, test_key)

      expect(test_duration[:worst]).to eq duration
      expect(test_duration[:best]).to eq duration
      expect(test_duration[:average]).to eq duration
    end
  end

  describe 'Parsing slowest JS test duration' do
    let(:raw_output_path) { 'succesful_run.txt' }

    it 'records the time of a JS slow test' do
      test_key = :acceptance_composer_actionsinteractions
      duration = 5.147

      output = subject.parse_raw_from(@archive)
      test_duration = output.dig(:slowest_js_tests, test_key)

      expect(test_duration[:worst]).to eq duration
      expect(test_duration[:best]).to eq duration
      expect(test_duration[:average]).to eq duration
    end
  end
end
