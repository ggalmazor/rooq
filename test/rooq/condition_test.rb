# frozen_string_literal: true

require "test_helper"

class ConditionTest < Minitest::Test
  # simple condition

  def test_stores_field_operator_and_value
    field = Rooq::Field.new(:title, :books, :string)
    condition = Rooq::Condition.new(field, :eq, "Hello")

    assert_that(condition.field).is(field)
    assert_that(condition.operator).equals(:eq)
    assert_that(condition.value).equals("Hello")
  end

  def test_freezes_after_creation
    field = Rooq::Field.new(:title, :books, :string)
    condition = Rooq::Condition.new(field, :eq, "Hello")

    assert_that(condition.frozen?).equals(true)
  end

  # and

  def test_and_creates_combined_condition_with_and_operator
    field = Rooq::Field.new(:title, :books, :string)
    cond1 = Rooq::Condition.new(field, :eq, "Hello")
    cond2 = Rooq::Condition.new(field, :ne, "World")

    combined = cond1.and(cond2)

    assert_that(combined).descends_from(Rooq::CombinedCondition)
    assert_that(combined.operator).equals(:and)
    assert_that(combined.conditions).equals([cond1, cond2])
  end

  # or

  def test_or_creates_combined_condition_with_or_operator
    field = Rooq::Field.new(:title, :books, :string)
    cond1 = Rooq::Condition.new(field, :eq, "Hello")
    cond2 = Rooq::Condition.new(field, :eq, "World")

    combined = cond1.or(cond2)

    assert_that(combined).descends_from(Rooq::CombinedCondition)
    assert_that(combined.operator).equals(:or)
  end
end

class CombinedConditionTest < Minitest::Test
  # initialization

  def test_freezes_after_creation
    field = Rooq::Field.new(:title, :books, :string)
    cond1 = Rooq::Condition.new(field, :eq, "Hello")
    cond2 = Rooq::Condition.new(field, :ne, "World")

    combined = Rooq::CombinedCondition.new(:and, [cond1, cond2])

    assert_that(combined.frozen?).equals(true)
  end

  # chaining

  def test_chains_multiple_and_conditions
    field = Rooq::Field.new(:title, :books, :string)
    cond1 = Rooq::Condition.new(field, :eq, "Hello")
    cond2 = Rooq::Condition.new(field, :ne, "World")
    cond3 = Rooq::Condition.new(field, :like, "%Ruby%")

    combined = cond1.and(cond2).and(cond3)

    assert_that(combined.conditions).has_size(3)
  end

  def test_chains_multiple_or_conditions
    field = Rooq::Field.new(:title, :books, :string)
    cond1 = Rooq::Condition.new(field, :eq, "Hello")
    cond2 = Rooq::Condition.new(field, :eq, "World")
    cond3 = Rooq::Condition.new(field, :like, "%Ruby%")

    combined = cond1.or(cond2).or(cond3)

    assert_that(combined.conditions).has_size(3)
  end
end
