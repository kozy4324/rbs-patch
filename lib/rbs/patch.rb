# frozen_string_literal: true

require "rbs"
require "stringio"
require_relative "patch/version"

module RBS
  class Patch # rubocop:disable Style/Documentation
    def initialize(source)
      @env = ::RBS::Environment.new
      apply(source)
    end

    def apply(source)
      _, dirs, decls = ::RBS::Parser.parse_signature(source)
      @env.add_source(::RBS::Source::RBS.new(source, dirs, decls))
      @env.class_decls.each_value.map do |class_entry|
        class_entry.context_decls.map { _2 }.inject do |decl_a, decl_b|
          decl_b.members.each do |member_b|
            if member_b.annotations.any? { |a| a.string == "override" }
              decl_a.members.delete_if { |member_a| member_a.name == member_b.name }
              member_b.annotations.delete_if { |a| a.string == "override" }
            end
          end
          decl_a
        end
      end
    end

    def to_s
      decls = @env.class_decls.each_value.map do |class_entry|
        decls = class_entry.context_decls.map { _2 }
        decls.each_with_object(decls.first.update(members: [])) do |decl, new_decl|
          # merge multiple class decls into a single one
          new_decl.members.concat decl.members
        end
      end

      io = ::StringIO.new
      RBS::Writer.new(out: io).write(decls)
      io.rewind
      io.read
    end
  end
end
