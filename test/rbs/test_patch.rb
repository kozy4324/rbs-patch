# frozen_string_literal: true

require "test_helper"

module RBS
  class TestPatch < Minitest::Test
    def test_single_rbs_file_converts_to_string
      p = RBS::Patch.new
      p.apply(<<~RBS)
        class A
          def a: () -> void
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class A
          def a: () -> void
        end
      EXPECTED
    end

    def test_merges_multiple_classes_into_single_file
      p = RBS::Patch.new
      p.apply(<<~RBS)
        class A
          def a: () -> void
        end
      RBS
      p.apply(<<~RBS)
        class A
          def b: () -> void
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class A
          def a: () -> void
          def b: () -> void
        end
      EXPECTED
    end

    def test_overrides_method_with_annotation
      p = RBS::Patch.new
      p.apply(<<~RBS)
        class A
          def a: () -> void
        end
      RBS
      p.apply(<<~RBS)
        class A
          %a{patch:override}
          def a: (untyped) -> untyped
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class A
          def a: (untyped) -> untyped
        end
      EXPECTED
    end

    def test_override_replaces_method_at_original_position
      p = RBS::Patch.new
      p.apply(<<~RBS)
        class A
          def a: () -> void
          def b: () -> void
          def c: () -> void
        end
      RBS
      p.apply(<<~RBS)
        class A
          %a{patch:override}
          def b: (untyped) -> untyped
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class A
          def a: () -> void
          def b: (untyped) -> untyped
          def c: () -> void
        end
      EXPECTED
    end

    def test_deletes_method
      p = RBS::Patch.new
      p.apply(<<~RBS)
        class A
          def a: () -> void
          def b: () -> void
          def c: () -> void
        end
      RBS
      p.apply(<<~RBS)
        class A
          %a{patch:delete}
          def b: () -> void
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class A
          def a: () -> void

          def c: () -> void
        end
      EXPECTED
    end

    def test_inserts_method_after_specific_method
      p = RBS::Patch.new
      p.apply(<<~RBS)
        class A
          def a: () -> void
          def b: () -> void
          def c: () -> void
        end
      RBS
      p.apply(<<~RBS)
        class A
          %a{patch:append_after(a)}
          def d: () -> void
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class A
          def a: () -> void
          def d: () -> void
          def b: () -> void
          def c: () -> void
        end
      EXPECTED
    end

    def test_inserts_method_before_specific_method
      p = RBS::Patch.new
      p.apply(<<~RBS)
        class A
          def a: () -> void
          def b: () -> void
          def c: () -> void
        end
      RBS
      p.apply(<<~RBS)
        class A
          %a{patch:prepend_before(a)}
          def d: () -> void
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class A
          def d: () -> void
          def a: () -> void
          def b: () -> void
          def c: () -> void
        end
      EXPECTED
    end

    def test_loads_from_file
      p = RBS::Patch.new
      p.apply(path: Pathname("#{__dir__}/../files/a.rbs"))
      p.apply(path: Pathname("#{__dir__}/../files/a_patch.rbs"))

      assert_equal(<<~EXPECTED, p.to_s)
        class A
          def a: (untyped) -> untyped
        end
      EXPECTED
    end

    def test_loads_from_directory
      p = RBS::Patch.new
      p.apply(path: Pathname("#{__dir__}/../files/dir_a"))
      p.apply(path: Pathname("#{__dir__}/../files/dir_b"))

      assert_equal(<<~EXPECTED, p.to_s)
        class A
          def a: (untyped) -> untyped
        end
        class B
          def b: () -> void
        end
      EXPECTED
    end

    def test_nested_module_structure
      p = RBS::Patch.new
      p.apply(<<~RBS)
        module M_OUTER
          module M_INNER
            class A
              def a: () -> void
            end
          end
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        module M_OUTER
          module M_INNER
            class A
              def a: () -> void
            end
          end
        end
      EXPECTED
    end

    def test_overrides_class_with_annotation
      p = RBS::Patch.new
      p.apply(<<~RBS)
        class A
          def a: () -> void
          def b: () -> void
        end
      RBS
      p.apply(<<~RBS)
        %a{patch:override}
        class A
          def a: (untyped) -> untyped
          def c: () -> void
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class A
          def a: (untyped) -> untyped
          def c: () -> void
        end
      EXPECTED
    end

    def test_deletes_class
      p = RBS::Patch.new
      p.apply(<<~RBS)
        class A
          def a: () -> void
        end
        class B
          def b: () -> void
        end
      RBS
      p.apply(<<~RBS)
        %a{patch:delete}
        class A
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class B
          def b: () -> void
        end
      EXPECTED
    end

    def test_inserts_class_after_specific_class
      p = RBS::Patch.new
      p.apply(<<~RBS)
        class A
          def a: () -> void
        end
        class B
          def b: () -> void
        end
        class C
          def c: () -> void
        end
      RBS
      p.apply(<<~RBS)
        %a{patch:append_after(A)}
        class D
          def d: () -> void
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class A
          def a: () -> void
        end
        class D
          def d: () -> void
        end
        class B
          def b: () -> void
        end
        class C
          def c: () -> void
        end
      EXPECTED
    end

    def test_inserts_class_before_specific_class
      p = RBS::Patch.new
      p.apply(<<~RBS)
        class A
          def a: () -> void
        end
        class B
          def b: () -> void
        end
        class C
          def c: () -> void
        end
      RBS
      p.apply(<<~RBS)
        %a{patch:prepend_before(A)}
        class D
          def d: () -> void
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class D
          def d: () -> void
        end
        class A
          def a: () -> void
        end
        class B
          def b: () -> void
        end
        class C
          def c: () -> void
        end
      EXPECTED
    end

    def test_inserts_class_after_specific_class_in_module
      p = RBS::Patch.new
      p.apply(<<~RBS)
        module M1
          module M2
            class A
              def a: () -> void
            end
            class B
              def b: () -> void
            end
          end
        end
        module M3
          class A
            def a: () -> void
          end
        end
      RBS
      p.apply(<<~RBS)
        module M1
          module M2
            %a{patch:append_after(A)}
            class C
              def c: () -> void
            end
          end
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        module M1
          module M2
            class A
              def a: () -> void
            end

            class C
              def c: () -> void
            end

            class B
              def b: () -> void
            end
          end
        end
        module M3
          class A
            def a: () -> void
          end
        end
      EXPECTED
    end

    def test_inserts_alias_after_specific_method
      p = RBS::Patch.new
      p.apply(<<~RBS)
        class A
          def a: () -> void
          def b: () -> void
          def c: () -> void
        end
      RBS
      p.apply(<<~RBS)
        class A
          %a{patch:append_after(a)}
          alias d a
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class A
          def a: () -> void
          alias d a
          def b: () -> void
          def c: () -> void
        end
      EXPECTED
    end

    def test_inserts_method_after_specific_alias
      p = RBS::Patch.new
      p.apply(<<~RBS)
        class A
          def a: () -> void
          alias b a
          def c: () -> void
        end
      RBS
      p.apply(<<~RBS)
        class A
          %a{patch:append_after(b)}
          def d: () -> void
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class A
          def a: () -> void
          alias b a
          def d: () -> void
          def c: () -> void
        end
      EXPECTED
    end

    def test_overrides_alias
      p = RBS::Patch.new
      p.apply(<<~RBS)
        class A
          def a: () -> void
          def b: () -> void
          alias c a
        end
      RBS
      p.apply(<<~RBS)
        class A
          %a{patch:override}
          alias c b
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class A
          def a: () -> void
          def b: () -> void
          alias c b
        end
      EXPECTED
    end

    def test_deletes_alias
      p = RBS::Patch.new
      p.apply(<<~RBS)
        class A
          def a: () -> void
          alias b a
        end
      RBS
      p.apply(<<~RBS)
        class A
          %a{patch:delete}
          alias b a
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class A
          def a: () -> void
        end
      EXPECTED
    end

    def test_inserts_multiple_methods_at_same_location
      p = RBS::Patch.new
      p.apply(<<~RBS)
        class A
          def a: () -> void
          def b: () -> void
        end
      RBS
      p.apply(<<~RBS)
        class A
          %a{patch:append_after(a)}
          def c: () -> void
          %a{patch:append_after(c)}
          def d: () -> void
          %a{patch:prepend_before(b)}
          def e: () -> void
          %a{patch:prepend_before(b)}
          def f: () -> void
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class A
          def a: () -> void
          def c: () -> void
          def d: () -> void
          def e: () -> void
          def f: () -> void
          def b: () -> void
        end
      EXPECTED
    end

    def test_inserts_multiple_aliases_at_same_location
      p = RBS::Patch.new
      p.apply(<<~RBS)
        class A
          def a: () -> void
          def b: () -> void
        end
      RBS
      p.apply(<<~RBS)
        class A
          %a{patch:append_after(a)}
          alias c a
          %a{patch:append_after(c)}
          alias d a
          %a{patch:prepend_before(b)}
          alias e a
          %a{patch:prepend_before(b)}
          alias f a
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class A
          def a: () -> void
          alias c a
          alias d a
          alias e a
          alias f a
          def b: () -> void
        end
      EXPECTED
    end

    def test_inserts_all_kinds_of_decls
      p = RBS::Patch.new
      # type t = Class | Module | Interface | Constant | Global | TypeAlias | ClassAlias | ModuleAlias
      p.apply(<<~RBS)
        class C1 end
        module M1 end
        interface _I1 end
        CONSTANT1: String
        $GLOBAL1: String
        type t1 = C1
        class CA1 = C1
        module MA1 = M1
      RBS
      p.apply(<<~RBS)
        %a{patch:append_after(C1)}
        class C2 end
        %a{patch:append_after(M1)}
        module M2 end
        %a{patch:append_after(_I1)}
        interface _I2 end
        %a{patch:append_after(CONSTANT1)}
        CONSTANT2: String
        %a{patch:append_after($GLOBAL1)}
        $GLOBAL2: String
        %a{patch:append_after(t1)}
        type t2 = C2
        %a{patch:append_after(CA1)}
        class CA2 = C2
        %a{patch:append_after(MA1)}
        module MA2 = M2
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class C1
        end
        class C2
        end
        module M1
        end
        module M2
        end
        interface _I1
        end
        interface _I2
        end
        CONSTANT1: String
        CONSTANT2: String
        $GLOBAL1: String
        $GLOBAL2: String
        type t1 = C1
        type t2 = C2
        class CA1 = C1
        class CA2 = C2
        module MA1 = M1
        module MA2 = M2
      EXPECTED
    end

    def test_inserts_all_kinds_of_members
      p = RBS::Patch.new
      # type t = MethodDefinition | InstanceVariable | ClassInstanceVariable | ClassVariable | Include | Extend
      #        | Prepend | AttrReader | AttrWriter | AttrAccessor | Public | Private | Alias
      p.apply(<<~RBS)
        class C
          def m1: () -> void
          @iv1: String
          self.@civ1: String
          @@cv1: String
          include Foo1
          extend Hoge1
          prepend Bar1
          attr_reader attrr1: String
          attr_writer attrw1: String
          attr_accessor attra1: String
          public
          def public_method1: () -> void
          private
          def private_method1: () -> void
          alias dest1 orig1
        end
      RBS
      p.apply(<<~RBS)
        class C
          %a{patch:append_after(m1)}
          def m2: () -> void
          @iv2: String
          self.@civ2: String
          @@cv2: String
          %a{patch:append_after(Foo1)}
          include Foo2
          %a{patch:append_after(Hoge1)}
          extend Hoge2
          %a{patch:append_after(Bar1)}
          prepend Bar2
          %a{patch:append_after(attrr1)}
          attr_reader attrr2: String
          %a{patch:append_after(attrw1)}
          attr_writer attrw2: String
          %a{patch:append_after(attra1)}
          attr_accessor attra2: String
          public
          %a{patch:append_after(public_method1)}
          def public_method2: () -> void
          private
          %a{patch:append_after(private_method1)}
          def private_method2: () -> void
          %a{patch:append_after(dest1)}
          alias dest2 orig2
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class C
          def m1: () -> void
          def m2: () -> void
          @iv1: String
          @iv2: String
          self.@civ1: String
          self.@civ2: String
          @@cv1: String
          @@cv2: String
          include Foo1
          include Foo2
          extend Hoge1
          extend Hoge2
          prepend Bar1
          prepend Bar2
          attr_reader attrr1: String
          attr_reader attrr2: String
          attr_writer attrw1: String
          attr_writer attrw2: String
          attr_accessor attra1: String
          attr_accessor attra2: String
          public
          def public_method1: () -> void
          def public_method2: () -> void
          private
          def private_method1: () -> void
          def private_method2: () -> void
          alias dest1 orig1
          alias dest2 orig2
        end
      EXPECTED
    end

    def test_inserts_variables_after_same_kind
      p = RBS::Patch.new
      p.apply(<<~RBS)
        class C
          @@cv: String
          @iv1: String
          self.@civ: String
          def m: () -> void
        end
      RBS
      p.apply(<<~RBS)
        class C
          @iv2: String
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class C
          @@cv: String
          @iv1: String
          @iv2: String

          self.@civ: String
          def m: () -> void
        end
      EXPECTED
    end

    def test_inserts_variables_before_methods_when_no_variable
      p = RBS::Patch.new
      p.apply(<<~RBS)
        class C
          def m1: () -> void
          def m2: () -> void
        end
      RBS
      p.apply(<<~RBS)
        class C
          @iv: String
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class C
          @iv: String
          def m1: () -> void
          def m2: () -> void
        end
      EXPECTED
    end

    def test_inserts_variables_last_when_no_variable_and_method
      p = RBS::Patch.new
      p.apply(<<~RBS)
        class C
          include M
        end
      RBS
      p.apply(<<~RBS)
        class C
          @iv: String
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class C
          include M
          @iv: String
        end
      EXPECTED
    end
  end
end
