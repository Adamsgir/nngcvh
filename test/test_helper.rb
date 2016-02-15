lib = File.expand_path File.join(File.dirname(__FILE__), '../lib')
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'test/unit'
require_relative '../lib/mdocker'
require_relative 'test_fixture'
require_relative 'test_base'

