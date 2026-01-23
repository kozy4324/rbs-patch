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
        next if process_context_decls(class_entry.context_decls)

        class_entry.context_decls.map { _2 }.inject do |decl_a, decl_b|
          process_members(decl_a.members, decl_b.members)
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

      classes = Set[]
      decls.each do |decl|
        decl.members.each do |member|
          classes << member.name if member.respond_to?(:name)
        end
      end
      decls.delete_if { |c| classes.include?(c.name) }

      io = ::StringIO.new
      RBS::Writer.new(out: io).write(decls)
      io.rewind
      io.read
    end

    private

    def process_annotations(annotations)
      if annotations.any? { |a| a.string == ANNOTATION_OVERRIDE }
        [:override, nil]
      elsif annotations.any? { |a| a.string == ANNOTATION_DELETE }
        [:delete, nil]
      elsif (anno = annotations.find { |a| a.string.match(ANNOTATION_APPEND_AFTER) })
        [:append_after, anno.string.match(ANNOTATION_APPEND_AFTER)[1]]
      elsif (anno = annotations.find { |a| a.string.match(ANNOTATION_PREPEND_BEFORE) })
        [:prepend_before, anno.string.match(ANNOTATION_PREPEND_BEFORE)[1]]
      end
    end

    def process_members(members_a, members_b)
      members_b.delete_if do |member_b|
        ope, arg = process_annotations(member_b.annotations)
        next unless ope

        case ope
        when :override
          index = members_a.find_index { |member_a| member_a.name == member_b.name }
          if index
            members_a[index] = members_a[index].update(overloads: member_b.overloads)
            true
          else
            false
          end
        when :delete
          members_a.reject! { |member_a| member_a.name == member_b.name }
        when :append_after, :prepend_before
          target_name = arg.to_sym
          index = members_a.find_index { |member_a| member_a.name == target_name }
          if index
            if ope == :append_after
              offset = 1
              annotations = member_b.annotations.reject { |a| a.string.match(ANNOTATION_APPEND_AFTER) }
            else
              offset = 0
              annotations = member_b.annotations.reject { |a| a.string.match(ANNOTATION_PREPEND_BEFORE) }
            end
            members_a.insert(index + offset, member_b.update(annotations:))
            true
          else
            false
          end
        end
      end
    end

    def process_context_decls(context_decls)
      context_decls.reject! do |_, decl|
        ope, = process_annotations(decl.annotations)
        next unless ope

        case ope
        when :override
          index = context_decls.find_index { |_, decl| decl.annotations.empty? }
          if index
            annotations = decl.annotations.reject { |a| a.string == ANNOTATION_OVERRIDE }
            context_decls[index] = [nil, decl.update(annotations:)]
            true
          else
            false
          end
          # when :delete
          #   members_a.reject! { |member_a| member_a.name == member_b.name }
          # when :append_after, :prepend_before
          #   target_name = arg.to_sym
          #   index = members_a.find_index { |member_a| member_a.name == target_name }
          #   if index
          #     if ope == :append_after
          #       offset = 1
          #       annotations = member_b.annotations.reject { |a| a.string.match(ANNOTATION_APPEND_AFTER) }
          #     else
          #       offset = 0
          #       annotations = member_b.annotations.reject { |a| a.string.match(ANNOTATION_PREPEND_BEFORE) }
          #     end
          #     members_a.insert(index + offset, member_b.update(annotations:))
          #     true
          #   else
          #     false
          #   end
        end
      end
    end
  end
end
