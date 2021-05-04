# frozen_string_literal: true

require_relative 'qunit_parser.rb'
require_relative 'rspec_parser.rb'

class BuildParser

  def self.default
    new([
      RSpecParser.new,
      QUnitParser.new,
      EmberCLITestsParser.new
    ])
  end

  def initialize(parsers)
    @parsers = parsers
  end

  def parse_raw_from(archive)
    state = archive.tests_report
    commit_hash = parse_commit_hash(archive)

    initial_report = {
      metadata: {
        runs: (state.dig(:metadata, :runs).to_i + 1),
        last_commit_hash: commit_hash,
        new_errors: false
      }
    }

    parsers.reduce(initial_report) do |memo, parser|
      parser.attatch_to_report(memo, archive, commit_hash)
    end
  end

  private

  attr_reader :parsers

  def parse_commit_hash(archive)
    checked_latest = false

    archive.raw_build_iterator.each do |line|
      checked_latest ||= line.include?("You are in 'detached HEAD' state.")

      if checked_latest && line.include?('HEAD is now at')
        return line.match(/HEAD is now at \s*(\S+)/)[1].gsub('...', '')
      end
    end
  end
end
