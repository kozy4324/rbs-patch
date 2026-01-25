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
      @decls = []
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

      process_class_decls @env.class_decls

      @env.class_decls.each_value.map do |class_entry|
        next if process_context_decls(class_entry.context_decls)

        class_entry.context_decls.map { _2 }.inject do |decl_a, decl_b|
          process_members(decl_a.members, decl_b.members)
          decl_a
        end
      end
    end

    def to_s
      unless @decls.empty?
        io = ::StringIO.new
        RBS::Writer.new(out: io).write(@decls)
        io.rewind
        return io.read
      end

      decls = @env.class_decls.each_value.map do |class_entry|
        decls = class_entry.context_decls.map { _2 }
        next if decls.empty?

        decls.each_with_object(decls.first.update(members: [])) do |decl, new_decl|
          # merge multiple class decls into a single one
          new_decl.members.concat decl.members
        end
      end.compact

      classes = Set[]
      decls.each do |decl|
        decl.members.each do |member|
          classes << member.name if member.respond_to?(:name)
        end
      end
      decls.delete_if { |c| classes.include?(c.name) }

      r = lambda { |member|
        if member.respond_to?(:members)
          member.members.delete_if { |m| m.respond_to?(:members) && m.members.empty? }
          member.members.each(&r)
        end
      }
      decls.each(&r)

      io = ::StringIO.new
      RBS::Writer.new(out: io).write(decls)
      io.rewind
      io.read
    end

    def apply2(source = nil, path: nil)
      unless path.nil?
        files = Set[]
        ::RBS::FileFinder.each_file(path, skip_hidden: true) do |path|
          next if files.include?(path)

          files << path
          apply2 Buffer.new(name: path, content: path.read(encoding: "UTF-8"))
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

      if map.key?(namespace)
        if after
          index = map[namespace].members.find_index { |m| m.name.to_s == after }
          map[namespace].members.insert(index + 1, decl)
        elsif before
          index = map[namespace].members.find_index { |m| m.name.to_s == before }
          map[namespace].members.insert(index, decl)
        else
          map[namespace].members << decl
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

      map[namespace].members.delete_if { |m| m.name.to_s == name }
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
          index = context_decls.find_index { |_, decl| decl.annotations.all? { |a| a.string != ANNOTATION_OVERRIDE } }
          if index
            annotations = decl.annotations.reject { |a| a.string == ANNOTATION_OVERRIDE }
            context_decls[index] = [nil, decl.update(annotations:)]
            true
          else
            false
          end
        when :delete
          target_name = decl.name
          context_decls.reject! { |_, decl| decl.name == target_name }
        end
      end
    end

    def process_class_decls(class_decls)
      ope = nil
      arg = nil
      name, = class_decls.find do |_, class_entry|
        class_entry.context_decls.any? do |_, decl|
          ope, arg = process_annotations(decl.annotations)
          %i[append_after prepend_before].include?(ope)
        end
      end
      return unless name

      anno_match = ->(a) { a.string.match(ANNOTATION_APPEND_AFTER) || a.string.match(ANNOTATION_PREPEND_BEFORE) }

      class_to_relocate = class_decls.delete(name)
      _, decl_to_relocate = class_to_relocate.context_decls.find { |_, decl| decl.annotations.any?(&anno_match) }
      decl_to_relocate.annotations.delete_if(&anno_match)

      target_key = RBS::TypeName.new(name: arg.to_sym, namespace: name.namespace)

      return unless class_decls.key? target_key

      offset = if ope == :append_after
                 1
               else
                 0
               end

      ary = class_decls.to_a
      class_decls.clear
      index = ary.find_index { |key, _| key == target_key }
      ary.insert(index + offset, [name, class_to_relocate])
      ary.each { |k, v| class_decls[k] = v }

      class_decls.each do |key, class_entry|
        class_entry.context_decls.map { _2 }.each do |decl|
          decl.members.delete(decl_to_relocate)
          index = decl.members.find_index do |m|
            RBS::TypeName.parse("#{key}::#{m.name}") == target_key
          end
          decl.members.insert(index + offset, decl_to_relocate) if index
        end
      end
    end
  end
end
