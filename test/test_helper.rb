# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "rooq"

require "minitest/autorun"
require "minicrest"

class Minitest::Test
  include Minicrest::Assertions
end
