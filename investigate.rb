# frozen_string_literal: true

# !/usr/bin/env ruby
require_relative 'lib/detective.rb'
require_relative 'lib/parsers/build_parser.rb'
require_relative 'lib/archives/file_system_archive.rb'

build_path = ARGV[0]
output_file_name = ARGV[1]

working_dir = File.expand_path(build_path, __FILE__)
archive = FileSystemArchive.new(working_dir, output_file_name)

Detective.new.investigate(BuildParser.new, archive)
