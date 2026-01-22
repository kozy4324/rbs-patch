# frozen_string_literal: true

require "rbs"
require "stringio"
require_relative "patch/version"

module RBS
  class Patch # rubocop:disable Style/Documentation
    ANNOTATION_OVERRIDE       = "patch:override"
    ANNOTATION_DELETE         = "patch:delete"
    ANNOTATION_APPEND_AFTER   = /\Apatch:append_after:(.*)\Z/
    ANNOTATION_PREPEND_BEFORE = /\Apatch:prepend_before:(.*)\Z/

    def initialize
      @env = ::RBS::Environment.new
    end

    def apply(source = nil, path: nil)
      unless path.nil?
        files = Set[]
        ::RBS::FileFinder.each_file(path, skip_hidden: true) do |path|
          next if files.include?(path)

          files << path
          apply Buffer.new(name: path, content: path.read(encoding: "UTF-8"))
        end
        return
      end

      _, dirs, decls = ::RBS::Parser.parse_signature(source)
      @env.add_source(::RBS::Source::RBS.new(source, dirs, decls))
      @env.class_decls.each_value.map do |class_entry|
        class_entry.context_decls.map { _2 }.inject do |decl_a, decl_b|
          decl_b.members.delete_if do |member_b|
            ope, arg = if member_b.annotations.any? { |a| a.string == ANNOTATION_OVERRIDE }
                         [:override, nil]
                       elsif member_b.annotations.any? { |a| a.string == ANNOTATION_DELETE }
                         [:delete, nil]
                       elsif (anno = member_b.annotations.find { |a| a.string.match(ANNOTATION_APPEND_AFTER) })
                         [:append_after, anno.string.match(ANNOTATION_APPEND_AFTER)[1]]
                       elsif (anno = member_b.annotations.find { |a| a.string.match(ANNOTATION_PREPEND_BEFORE) })
                         [:prepend_before, anno.string.match(ANNOTATION_PREPEND_BEFORE)[1]]
                       end

            next unless ope

            case ope
            when :override
              index = decl_a.members.find_index { |member_a| member_a.name == member_b.name }
              if index
                decl_a.members[index] = decl_a.members[index].update(overloads: member_b.overloads)
                true
              else
                false
              end
            when :delete
              decl_a.members.reject! { |member_a| member_a.name == member_b.name }
            when :append_after, :prepend_before
              target_name = arg.to_sym
              index = decl_a.members.find_index { |member_a| member_a.name == target_name }
              if index
                if ope == :append_after
                  offset = 1
                  annotations = member_b.annotations.reject { |a| a.string.match(ANNOTATION_APPEND_AFTER) }
                else
                  offset = 0
                  annotations = member_b.annotations.reject { |a| a.string.match(ANNOTATION_PREPEND_BEFORE) }
                end
                decl_a.members.insert(index + offset, member_b.update(annotations:))
                true
              else
                false
              end
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
