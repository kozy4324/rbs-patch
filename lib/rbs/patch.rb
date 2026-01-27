# frozen_string_literal: true

require "rbs"
require "stringio"
require_relative "patch/version"

module RBS
  class Patch # rubocop:disable Style/Documentation
    ANNOTATION_OVERRIDE       = "patch:override"
    ANNOTATION_DELETE         = "patch:delete"
    ANNOTATION_APPEND_AFTER   = /\Apatch:append_after\((.*)\)\Z/
    ANNOTATION_PREPEND_BEFORE = /\Apatch:prepend_before\((.*)\)\Z/

    def initialize
      @decls = []
    end

    def to_s
      io = ::StringIO.new
      ::RBS::Writer.new(out: io).write(@decls)
      io.rewind
      io.read || ""
    end

    def apply(source = nil, path: nil)
      unless path.nil?
        files = Set[]
        ::RBS::FileFinder.each_file(path, skip_hidden: true) do |path|
          next if files.include?(path)

          files << path
          apply ::RBS::Buffer.new(name: path, content: path.read(encoding: "UTF-8"))
        end
        return
      end

      _, _, decls = ::RBS::Parser.parse_signature(source)
      walk(decls) do |decl, name|
        ope, arg = process_annotations(decl.annotations) if decl.respond_to?(:annotations) # steep:ignore

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

    def extract_name(decl)
      if decl.is_a?(::RBS::AST::Declarations::AliasDecl) # rubocop:disable Style/CaseLikeIf
        decl.new_name.to_s
      elsif decl.is_a?(::RBS::AST::Declarations::Base)
        decl.name.to_s
      elsif decl.is_a?(::RBS::AST::Members::LocationOnly)
        ""
      elsif decl.is_a?(::RBS::AST::Members::Alias) # rubocop:disable Lint/DuplicateBranch
        decl.new_name.to_s
      else # rubocop:disable Lint/DuplicateBranch
        # ::RBS::AST::Members::t
        decl.name.to_s
      end
    end

    def extract_members(decl)
      decl.members if decl.is_a?(::RBS::AST::Declarations::NestedDeclarationHelper)
    end

    def walk(decls, name_stack = [], &block)
      decls.each do |decl|
        name_stack << extract_name(decl)
        if decl.is_a?(::RBS::AST::Members::Base)
          yield decl, "#{name_stack[..-2]&.join("::")}##{name_stack[-1]}"
        else
          yield decl, name_stack.join("::")
        end
        members = extract_members(decl)
        walk(members, name_stack, &block) if members
        name_stack.pop
      end
    end

    def decl_map
      # @type var map: Hash[String, ::RBS::Patch::t]
      map = {}
      walk(@decls) { |decl, name| map[name] = decl }
      map
    end

    def add(decl, to:, after: nil, before: nil)
      map = decl_map
      return if map.key?(to)

      sep = decl.is_a?(::RBS::AST::Members::Base) ? "#" : "::"
      namespace, = to.rpartition(sep)

      target = namespace.empty? ? @decls : extract_members(map[namespace])

      if target
        if after
          index = target.find_index { |m| extract_name(m) == after }
          target.insert(index + 1, decl) if index
        elsif before
          index = target.find_index { |m| extract_name(m) == before }
          target.insert(index, decl) if index
        else
          target << decl
        end
        decl.annotations.delete_if { |a| process_annotations([a]) } # steep:ignore
      else
        @decls << decl # steep:ignore
      end
    end

    def override(name, with:)
      map = decl_map
      return unless map.key?(name)

      sep = with.is_a?(::RBS::AST::Members::Base) ? "#" : "::"
      namespace, _, name = name.rpartition(sep)

      if namespace.empty?
        # top level decl
        index = @decls.find_index { |d| extract_name(d) == name }
        @decls[index] = with # steep:ignore
      else
        members = extract_members(map[namespace])
        index = members.find_index do |m| # steep:ignore
          extract_name(m) == name
        end
        members[index] = with # steep:ignore
      end
      with.annotations.delete_if { |a| process_annotations([a]) } # steep:ignore
    end

    def delete(name)
      map = decl_map
      return unless map.key?(name)

      sep = name.index("#") ? "#" : "::"
      namespace, _, name = name.rpartition(sep)

      if namespace.empty?
        # top level decl
        @decls.delete_if { |d| extract_name(d) == name }
      else
        extract_members(map[namespace])&.delete_if { |m| extract_name(m) == name }
      end
    end

    def process_annotations(annotations) # steep:ignore
      if annotations.any? { |a| a.string == ANNOTATION_OVERRIDE }
        [:override, nil]
      elsif annotations.any? { |a| a.string == ANNOTATION_DELETE }
        [:delete, nil]
      elsif (anno = annotations.find { |a| a.string.match(ANNOTATION_APPEND_AFTER) })
        [:append_after, anno.string.match(ANNOTATION_APPEND_AFTER)&.[](1) || ""]
      elsif (anno = annotations.find { |a| a.string.match(ANNOTATION_PREPEND_BEFORE) })
        [:prepend_before, anno.string.match(ANNOTATION_PREPEND_BEFORE)&.[](1) || ""]
      end
    end
  end
end
