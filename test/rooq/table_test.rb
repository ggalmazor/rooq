# frozen_string_literal: true

require "test_helper"

class TableTest < Minitest::Test
  # initialization

  def test_stores_the_table_name
    table = Rooq::Table.new(:books)

    assert_that(table.name).equals(:books)
  end

  def test_freezes_after_creation
    table = Rooq::Table.new(:books)

    assert_that(table.frozen?).equals(true)
  end

  # field definition

  def test_allows_defining_fields_with_a_block
    table = Rooq::Table.new(:books) do |t|
      t.field :id, :integer
      t.field :title, :string
      t.field :published_at, :datetime
    end

    assert_that(table.fields.size).equals(3)
    assert_that(table.fields[:id].name).equals(:id)
    assert_that(table.fields[:title].type).equals(:string)
  end

  def test_sets_table_reference_on_fields
    table = Rooq::Table.new(:books) do |t|
      t.field :title, :string
    end

    assert_that(table.fields[:title].table_name).equals(:books)
  end

  # field accessors

  def test_provides_uppercase_method_accessors_for_fields
    table = Rooq::Table.new(:books) do |t|
      t.field :title, :string
    end

    assert_that(table.TITLE).descends_from(Rooq::Field)
    assert_that(table.TITLE.name).equals(:title)
  end

  def test_raises_validation_error_for_unknown_fields_with_helpful_message
    table = Rooq::Table.new(:books) do |t|
      t.field :title, :string
    end

    error = assert_raises(Rooq::ValidationError) { table.UNKNOWN_FIELD }
    assert_that(error.message).matches_pattern(/Unknown field 'unknown_field' on table 'books'/)
  end

  # asterisk

  def test_asterisk_returns_all_fields_in_definition_order
    table = Rooq::Table.new(:books) do |t|
      t.field :id, :integer
      t.field :title, :string
    end

    all_fields = table.asterisk

    assert_that(all_fields).has_size(2)
    assert_that(all_fields.map(&:name)).equals([:id, :title])
  end
end
