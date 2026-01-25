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
      @decls = []
    end

    def to_s
      io = ::StringIO.new
      RBS::Writer.new(out: io).write(@decls)
      io.rewind
      io.read
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

      _, _, decls = ::RBS::Parser.parse_signature(source)
      walk(decls) do |decl, name|
        ope, arg = process_annotations(decl.annotations)

        case ope
        when :override
          override(name, with: decl)
        when :delete
          delete(name)
        when :append_after
          add(decl, to: name, after: arg)
        when :prepend_before
          add(decl, to: name, before: arg)
        else
          add(decl, to: name)
        end
      end
    end

    private

    def walk(decls, name_stack = [], &block)
      decls.each do |decl|
        name_stack << decl.name.to_s
        if decl.is_a?(RBS::AST::Members::Base)
          yield decl, "::#{name_stack[..-2].join("::")}##{name_stack[-1]}"
        else
          yield decl, "::#{name_stack.join("::")}"
        end
        walk(decl.members, name_stack, &block) if decl.respond_to?(:members)
        name_stack.pop
      end
    end

    def decl_map
      map = {}
      walk(@decls) { |decl, name| map[name] = decl }
      map
    end

    def add(decl, to:, after: nil, before: nil)
      map = decl_map
      return if map.key?(to)

      sep = decl.is_a?(RBS::AST::Members::Base) ? "#" : "::"
      namespace, = to.rpartition(sep)

      target = namespace.empty? ? @decls : map[namespace]&.members

      if target
        if after
          index = target.find_index { |m| m.name.to_s == after }
          target.insert(index + 1, decl)
        elsif before
          index = target.find_index { |m| m.name.to_s == before }
          target.insert(index, decl)
        else
          target << decl
        end
        decl.annotations.delete_if { |a| process_annotations([a]) }
      else
        @decls << decl
      end
    end

    def override(name, with:)
      map = decl_map
      return unless map.key?(name)

      sep = with.is_a?(RBS::AST::Members::Base) ? "#" : "::"
      namespace, _, name = name.rpartition(sep)

      if namespace.empty?
        # top level decl
        index = @decls.find_index { |d| d.name.to_s == name }
        @decls[index] = with
      else
        index = map[namespace].members.find_index do |m|
          m.name.to_s == name
        end
        map[namespace].members[index] = with
      end
      with.annotations.delete_if { |a| process_annotations([a]) }
    end

    def delete(name)
      map = decl_map
      return unless map.key?(name)

      sep = name.index("#") ? "#" : "::"
      namespace, _, name = name.rpartition(sep)

      if namespace.empty?
        # top level decl
        @decls.delete_if { |d| d.name.to_s == name }
      else
        map[namespace].members.delete_if { |m| m.name.to_s == name }
      end
    end

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
  end
end
