# frozen_string_literal: true

require "test_helper"

class FieldTest < Minitest::Test
  # initialization

  def test_stores_name_table_name_and_type
    field = Rooq::Field.new(:title, :books, :string)

    assert_that(field.name).equals(:title)
    assert_that(field.table_name).equals(:books)
    assert_that(field.type).equals(:string)
  end

  def test_freezes_the_field_after_creation
    field = Rooq::Field.new(:title, :books, :string)

    assert_that(field.frozen?).equals(true)
  end

  # qualified_name

  def test_qualified_name_returns_table_column_format
    field = Rooq::Field.new(:title, :books, :string)

    assert_that(field.qualified_name).equals("books.title")
  end

  # comparison operators

  def test_eq_creates_condition
    field = Rooq::Field.new(:title, :books, :string)
    condition = field.eq("Hello World")

    assert_that(condition).descends_from(Rooq::Condition)
    assert_that(condition.operator).equals(:eq)
    assert_that(condition.field).is(field)
    assert_that(condition.value).equals("Hello World")
  end

  def test_ne_creates_condition
    field = Rooq::Field.new(:id, :books, :integer)
    condition = field.ne(5)

    assert_that(condition.operator).equals(:ne)
    assert_that(condition.value).equals(5)
  end

  def test_gt_creates_condition
    field = Rooq::Field.new(:price, :books, :decimal)
    condition = field.gt(10.0)

    assert_that(condition.operator).equals(:gt)
    assert_that(condition.value).equals(10.0)
  end

  def test_lt_creates_condition
    field = Rooq::Field.new(:price, :books, :decimal)
    condition = field.lt(20.0)

    assert_that(condition.operator).equals(:lt)
  end

  def test_gte_creates_condition
    field = Rooq::Field.new(:price, :books, :decimal)
    condition = field.gte(10.0)

    assert_that(condition.operator).equals(:gte)
  end

  def test_lte_creates_condition
    field = Rooq::Field.new(:price, :books, :decimal)
    condition = field.lte(20.0)

    assert_that(condition.operator).equals(:lte)
  end

  def test_in_creates_condition
    field = Rooq::Field.new(:status, :books, :string)
    condition = field.in(%w[active pending])

    assert_that(condition.operator).equals(:in)
    assert_that(condition.value).equals(%w[active pending])
  end

  def test_like_creates_condition
    field = Rooq::Field.new(:title, :books, :string)
    condition = field.like("%Ruby%")

    assert_that(condition.operator).equals(:like)
    assert_that(condition.value).equals("%Ruby%")
  end

  def test_between_creates_condition
    field = Rooq::Field.new(:price, :books, :decimal)
    condition = field.between(10, 20)

    assert_that(condition.operator).equals(:between)
    assert_that(condition.value).equals([10, 20])
  end

  def test_is_null_creates_condition
    field = Rooq::Field.new(:deleted_at, :books, :datetime)
    condition = field.is_null

    assert_that(condition.operator).equals(:is_null)
    assert_that(condition.value).is(nil_value)
  end

  def test_is_not_null_creates_condition
    field = Rooq::Field.new(:deleted_at, :books, :datetime)
    condition = field.is_not_null

    assert_that(condition.operator).equals(:is_not_null)
  end

  # ordering

  def test_asc_creates_order_specification
    field = Rooq::Field.new(:title, :books, :string)
    order = field.asc

    assert_that(order).descends_from(Rooq::OrderSpecification)
    assert_that(order.field).is(field)
    assert_that(order.direction).equals(:asc)
  end

  def test_desc_creates_order_specification
    field = Rooq::Field.new(:created_at, :books, :datetime)
    order = field.desc

    assert_that(order.direction).equals(:desc)
  end
end
