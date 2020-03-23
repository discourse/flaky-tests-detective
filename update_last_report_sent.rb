# frozen_string_literal: true

# !/usr/bin/env ruby
require_relative 'lib/archives/file_system_archive.rb'

report_filename = 'build_report.json'
working_dir = File.expand_path('../reports', __FILE__)
archive = FileSystemArchive.new(working_dir, report_filename)

archive.update_last_report_sent
