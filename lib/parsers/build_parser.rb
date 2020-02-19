# frozen_string_literal: true

require_relative 'qunit_parser.rb'
require_relative 'rspec_parser.rb'

class BuildParser

  def initialize
    @rspec_parser = RSpecParser.new
    @qunit_parser = QUnitParser.new
  end

  def parse_raw_from(archive)
    state = archive.tests_report
    state[:slowest_ruby_tests] ||= {}
    state[:slowest_js_tests] ||= {}

    commit_hash = parse_commit_hash(archive)
    ruby_errors = rspec_parser.errors(state[:ruby_tests], archive, commit_hash)
    js_errors = qunit_parser.errors(state[:js_tests], archive, commit_hash)
    slowest_ruby_tests = rspec_parser.slowest_tests(state[:slowest_ruby_tests], archive, commit_hash)
    slowest_js_tests = qunit_parser.slowest_tests(state[:slowest_js_tests], archive, commit_hash)

    {
      metadata: {
        runs: (state.dig(:metadata, :runs) + 1),
        last_commit_hash: commit_hash,
        new_errors: ruby_errors[:new_errors] || js_errors[:new_errors]
      },
      ruby_tests: ruby_errors[:errors],
      js_tests: js_errors[:errors],
      slowest_ruby_tests: slowest_ruby_tests,
      slowest_js_tests: slowest_js_tests
    }
  end

  private

  attr_reader :rspec_parser, :qunit_parser

  def parse_commit_hash(archive)
    checked_latest = false

    result = archive.raw_build_iterator.each do |line|
      checked_latest ||= line.include?("You are in 'detached HEAD' state.")

      if checked_latest && line.include?('HEAD is now at')
        return line.match(/HEAD is now at \s*(\S+)/)[1].gsub('...', '')
      end
    end
  end
end
