# frozen_string_literal: true

# !/usr/bin/env ruby
require_relative 'lib/detective.rb'
require_relative 'lib/printers/markdown_printer.rb'
require_relative 'lib/archives/file_system_archive.rb'

report_filename = ARGV[0] || 'build_report.json'
threshold = 3

working_dir = File.expand_path('../reports', __FILE__)
archive = FileSystemArchive.new(working_dir, report_filename)

report = Detective.new.report_for(threshold, archive)
puts MarkdownPrinter.new.print_from(report)
