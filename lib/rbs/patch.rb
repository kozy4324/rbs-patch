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
          decl_b.members.delete_if do |member_b|
            next false unless member_b.annotations.any? { |a| a.string == "override" }

            index = decl_a.members.find_index { |member_a| member_a.name == member_b.name }
            if index
              decl_a.members[index] = decl_a.members[index].update(overloads: member_b.overloads)
              true
            else
              false
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
