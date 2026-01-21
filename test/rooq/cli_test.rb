# frozen_string_literal: true

require "test_helper"
require "rooq/cli"

class CLITest < Minitest::Test
  # help command

  def test_help_command_returns_success
    cli = Rooq::CLI.new(["help"])

    result = capture_io { cli.run }

    assert_that(result[0]).includes("rOOQ - A jOOQ-inspired query builder for Ruby")
  end

  def test_help_command_shows_usage
    cli = Rooq::CLI.new(["help"])

    result = capture_io { cli.run }

    assert_that(result[0]).includes("Usage: rooq <command>")
    assert_that(result[0]).includes("generate, gen, g")
  end

  # version command

  def test_version_command_returns_success
    cli = Rooq::CLI.new(["version"])

    result = capture_io { cli.run }

    assert_that(result[0]).includes("rooq #{Rooq::VERSION}")
  end

  # generate command

  def test_generate_requires_database_option
    cli = Rooq::CLI.new(["generate"])

    result = capture_io { exit_code = cli.run; assert_that(exit_code).equals(1) }

    assert_that(result[1]).includes("Database name is required")
  end

  # unknown command

  def test_unknown_command_returns_error
    cli = Rooq::CLI.new(["unknown"])

    result = capture_io { exit_code = cli.run; assert_that(exit_code).equals(1) }

    assert_that(result[1]).includes("Unknown command: unknown")
  end
end
