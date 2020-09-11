# frozen_string_literal: true

# !/usr/bin/env ruby
require_relative 'lib/detective.rb'
require_relative 'lib/printers/markdown_printer.rb'
require_relative 'lib/archives/file_system_archive.rb'
require 'discourse_api'

discourse_url = ARGV[0]
api_key = ARGV[1]
username = ARGV[2]
topic_id = ARGV[3]

client = DiscourseApi::Client.new(discourse_url)
client.api_key = api_key
client.api_username = username

working_dir = File.expand_path('../reports', __FILE__)
archive = FileSystemArchive.new(working_dir, 'build_report.json')
threshold = 3

Detective.new.report_to(client, topic_id, MarkdownPrinter.new, archive, threshold)
