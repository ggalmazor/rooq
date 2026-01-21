# frozen_string_literal: true

module Rooq
  class Record
    class << self
      attr_accessor :table, :executor, :primary_key

      def inherited(subclass)
        subclass.primary_key = :id
      end

      def find(id)
        query = DSL.select(*table.asterisk)
                   .from(table)
                   .where(table.send(primary_key.upcase).eq(id))

        row = executor.fetch_one(query)
        return nil unless row

        from_row(row)
      end

      def find_by(conditions)
        condition = build_condition(conditions)
        query = DSL.select(*table.asterisk)
                   .from(table)
                   .where(condition)

        row = executor.fetch_one(query)
        return nil unless row

        from_row(row)
      end

      def where(conditions)
        condition = build_condition(conditions)
        query = DSL.select(*table.asterisk)
                   .from(table)
                   .where(condition)

        executor.fetch_all(query).map { |row| from_row(row) }
      end

      def all
        query = DSL.select(*table.asterisk).from(table)
        executor.fetch_all(query).map { |row| from_row(row) }
      end

      def create(attributes)
        record = new(attributes)
        record.save
        record
      end

      def from_row(row)
        attributes = {}
        table.fields.each_key do |field_name|
          attributes[field_name] = row[field_name.to_s]
        end
        record = new(attributes)
        record.instance_variable_set(:@persisted, true)
        record.instance_variable_set(:@changed_attributes, {})
        record
      end

      private

      def build_condition(conditions)
        conditions.reduce(nil) do |combined, (field_name, value)|
          field = table.send(field_name.upcase)
          condition = field.eq(value)
          combined ? combined.and(condition) : condition
        end
      end
    end

    attr_reader :attributes, :changed_attributes

    def initialize(attributes = {})
      @attributes = {}
      @changed_attributes = {}
      @persisted = false

      attributes.each do |key, value|
        @attributes[key.to_sym] = value
        @changed_attributes[key.to_sym] = value
      end
    end

    def [](key)
      @attributes[key.to_sym]
    end

    def []=(key, value)
      key = key.to_sym
      old_value = @attributes[key]
      return if old_value == value

      @attributes[key] = value
      @changed_attributes[key] = value
    end

    def persisted?
      @persisted
    end

    def new_record?
      !@persisted
    end

    def changed?
      !@changed_attributes.empty?
    end

    def changes
      @changed_attributes.dup
    end

    def save
      if persisted?
        update_record
      else
        insert_record
      end
    end

    def destroy
      return false unless persisted?

      pk_field = self.class.table.send(self.class.primary_key.upcase)
      query = DSL.delete_from(self.class.table)
                 .where(pk_field.eq(@attributes[self.class.primary_key]))

      self.class.executor.execute(query)
      @persisted = false
      true
    end

    def reload
      return self unless persisted?

      pk_value = @attributes[self.class.primary_key]
      reloaded = self.class.find(pk_value)
      return nil unless reloaded

      @attributes = reloaded.attributes.dup
      @changed_attributes = {}
      self
    end

    private

    def insert_record
      table = self.class.table
      columns = []
      values = []

      @changed_attributes.each do |key, value|
        next if key == self.class.primary_key && value.nil?

        columns << table.send(key.upcase)
        values << value
      end

      pk_field = table.send(self.class.primary_key.upcase)

      query = DSL.insert_into(table)
                 .columns(*columns)
                 .values(*values)
                 .returning(pk_field)

      result = self.class.executor.fetch_one(query)
      @attributes[self.class.primary_key] = result[self.class.primary_key.to_s].to_i if result
      @persisted = true
      @changed_attributes = {}
      true
    end

    def update_record
      return true if @changed_attributes.empty?

      table = self.class.table
      pk_field = table.send(self.class.primary_key.upcase)

      query = DSL.update(table)

      @changed_attributes.each do |key, value|
        next if key == self.class.primary_key

        field = table.send(key.upcase)
        query = query.set(field, value)
      end

      query = query.where(pk_field.eq(@attributes[self.class.primary_key]))

      self.class.executor.execute(query)
      @changed_attributes = {}
      true
    end
  end
end
