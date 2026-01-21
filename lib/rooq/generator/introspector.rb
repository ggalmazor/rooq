# frozen_string_literal: true

module Rooq
  module Generator
    class Introspector
      PG_TYPE_MAP = {
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
      }.freeze

      def initialize(connection)
        @connection = connection
      end

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

      def map_pg_type(pg_type)
        PG_TYPE_MAP.fetch(pg_type.downcase, :unknown)
      end
    end

    class ColumnInfo
      attr_reader :name, :type, :pg_type, :nullable, :default, :max_length, :precision, :scale

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
      attr_reader :column_name, :foreign_table, :foreign_column

      def initialize(column_name:, foreign_table:, foreign_column:)
        @column_name = column_name
        @foreign_table = foreign_table
        @foreign_column = foreign_column
        freeze
      end
    end

    class TableInfo
      attr_reader :name, :columns, :primary_keys, :foreign_keys

      def initialize(name:, columns:, primary_keys:, foreign_keys:)
        @name = name
        @columns = columns.freeze
        @primary_keys = primary_keys.freeze
        @foreign_keys = foreign_keys.freeze
        freeze
      end
    end
  end
end
