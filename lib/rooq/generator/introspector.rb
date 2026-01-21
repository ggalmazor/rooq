# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module Rooq
  module Generator
    class Introspector
      extend T::Sig

      PG_TYPE_MAP = T.let({
        "integer" => :integer,
        "bigint" => :bigint,
        "smallint" => :smallint,
        "serial" => :integer,
        "bigserial" => :bigint,
        "real" => :float,
        "double precision" => :double,
        "numeric" => :decimal,
        "decimal" => :decimal,
        "character varying" => :string,
        "varchar" => :string,
        "character" => :string,
        "char" => :string,
        "text" => :text,
        "boolean" => :boolean,
        "date" => :date,
        "timestamp without time zone" => :datetime,
        "timestamp with time zone" => :datetime_tz,
        "time without time zone" => :time,
        "time with time zone" => :time_tz,
        "uuid" => :uuid,
        "json" => :json,
        "jsonb" => :jsonb,
        "bytea" => :binary,
        "inet" => :inet,
        "cidr" => :cidr,
        "macaddr" => :macaddr
      }.freeze, T::Hash[String, Symbol])

      sig { params(connection: T.untyped).void }
      def initialize(connection)
        @connection = connection
      end

      sig { params(schema: String).returns(T::Array[String]) }
      def introspect_tables(schema: "public")
        tables_sql = <<~SQL
          SELECT table_name
          FROM information_schema.tables
          WHERE table_schema = $1
            AND table_type = 'BASE TABLE'
          ORDER BY table_name
        SQL

        result = @connection.exec_params(tables_sql, [schema])
        result.map { |row| row["table_name"] }
      end

      sig { params(table_name: String, schema: String).returns(T::Array[ColumnInfo]) }
      def introspect_columns(table_name, schema: "public")
        columns_sql = <<~SQL
          SELECT
            column_name,
            data_type,
            is_nullable,
            column_default,
            character_maximum_length,
            numeric_precision,
            numeric_scale
          FROM information_schema.columns
          WHERE table_schema = $1
            AND table_name = $2
          ORDER BY ordinal_position
        SQL

        result = @connection.exec_params(columns_sql, [schema, table_name])
        result.map do |row|
          ColumnInfo.new(
            name: row["column_name"],
            type: map_pg_type(row["data_type"]),
            pg_type: row["data_type"],
            nullable: row["is_nullable"] == "YES",
            default: row["column_default"],
            max_length: row["character_maximum_length"]&.to_i,
            precision: row["numeric_precision"]&.to_i,
            scale: row["numeric_scale"]&.to_i
          )
        end
      end

      sig { params(table_name: String, schema: String).returns(T::Array[String]) }
      def introspect_primary_keys(table_name, schema: "public")
        pk_sql = <<~SQL
          SELECT kcu.column_name
          FROM information_schema.table_constraints tc
          JOIN information_schema.key_column_usage kcu
            ON tc.constraint_name = kcu.constraint_name
            AND tc.table_schema = kcu.table_schema
          WHERE tc.constraint_type = 'PRIMARY KEY'
            AND tc.table_schema = $1
            AND tc.table_name = $2
          ORDER BY kcu.ordinal_position
        SQL

        result = @connection.exec_params(pk_sql, [schema, table_name])
        result.map { |row| row["column_name"] }
      end

      sig { params(table_name: String, schema: String).returns(T::Array[ForeignKeyInfo]) }
      def introspect_foreign_keys(table_name, schema: "public")
        fk_sql = <<~SQL
          SELECT
            kcu.column_name,
            ccu.table_name AS foreign_table_name,
            ccu.column_name AS foreign_column_name
          FROM information_schema.table_constraints tc
          JOIN information_schema.key_column_usage kcu
            ON tc.constraint_name = kcu.constraint_name
            AND tc.table_schema = kcu.table_schema
          JOIN information_schema.constraint_column_usage ccu
            ON ccu.constraint_name = tc.constraint_name
            AND ccu.table_schema = tc.table_schema
          WHERE tc.constraint_type = 'FOREIGN KEY'
            AND tc.table_schema = $1
            AND tc.table_name = $2
        SQL

        result = @connection.exec_params(fk_sql, [schema, table_name])
        result.map do |row|
          ForeignKeyInfo.new(
            column_name: row["column_name"],
            foreign_table: row["foreign_table_name"],
            foreign_column: row["foreign_column_name"]
          )
        end
      end

      sig { params(schema: String).returns(T::Array[TableInfo]) }
      def introspect_schema(schema: "public")
        tables = introspect_tables(schema: schema)
        tables.map do |table_name|
          TableInfo.new(
            name: table_name,
            columns: introspect_columns(table_name, schema: schema),
            primary_keys: introspect_primary_keys(table_name, schema: schema),
            foreign_keys: introspect_foreign_keys(table_name, schema: schema)
          )
        end
      end

      private

      sig { params(pg_type: String).returns(Symbol) }
      def map_pg_type(pg_type)
        PG_TYPE_MAP.fetch(pg_type.downcase, :unknown)
      end
    end

    class ColumnInfo
      extend T::Sig

      sig { returns(String) }
      attr_reader :name

      sig { returns(Symbol) }
      attr_reader :type

      sig { returns(String) }
      attr_reader :pg_type

      sig { returns(T::Boolean) }
      attr_reader :nullable

      sig { returns(T.nilable(String)) }
      attr_reader :default

      sig { returns(T.nilable(Integer)) }
      attr_reader :max_length

      sig { returns(T.nilable(Integer)) }
      attr_reader :precision

      sig { returns(T.nilable(Integer)) }
      attr_reader :scale

      sig do
        params(
          name: String,
          type: Symbol,
          pg_type: String,
          nullable: T::Boolean,
          default: T.nilable(String),
          max_length: T.nilable(Integer),
          precision: T.nilable(Integer),
          scale: T.nilable(Integer)
        ).void
      end
      def initialize(name:, type:, pg_type:, nullable:, default:, max_length:, precision:, scale:)
        @name = name
        @type = type
        @pg_type = pg_type
        @nullable = nullable
        @default = default
        @max_length = max_length
        @precision = precision
        @scale = scale
        freeze
      end
    end

    class ForeignKeyInfo
      extend T::Sig

      sig { returns(String) }
      attr_reader :column_name

      sig { returns(String) }
      attr_reader :foreign_table

      sig { returns(String) }
      attr_reader :foreign_column

      sig { params(column_name: String, foreign_table: String, foreign_column: String).void }
      def initialize(column_name:, foreign_table:, foreign_column:)
        @column_name = column_name
        @foreign_table = foreign_table
        @foreign_column = foreign_column
        freeze
      end
    end

    class TableInfo
      extend T::Sig

      sig { returns(String) }
      attr_reader :name

      sig { returns(T::Array[ColumnInfo]) }
      attr_reader :columns

      sig { returns(T::Array[String]) }
      attr_reader :primary_keys

      sig { returns(T::Array[ForeignKeyInfo]) }
      attr_reader :foreign_keys

      sig do
        params(
          name: String,
          columns: T::Array[ColumnInfo],
          primary_keys: T::Array[String],
          foreign_keys: T::Array[ForeignKeyInfo]
        ).void
      end
      def initialize(name:, columns:, primary_keys:, foreign_keys:)
        @name = name
        @columns = T.let(columns.freeze, T::Array[ColumnInfo])
        @primary_keys = T.let(primary_keys.freeze, T::Array[String])
        @foreign_keys = T.let(foreign_keys.freeze, T::Array[ForeignKeyInfo])
        freeze
      end
    end
  end
end
