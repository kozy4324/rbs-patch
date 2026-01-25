# frozen_string_literal: true

require "test_helper"

module RBS
  class TestPatch < Minitest::Test
    def test_single_rbs_file_converts_to_string
      p = RBS::Patch.new
      p.apply2(<<~RBS)
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
      p.apply2(<<~RBS)
        class A
          def a: () -> void
        end
      RBS
      p.apply2(<<~RBS)
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
      p.apply2(<<~RBS)
        class A
          def a: () -> void
        end
      RBS
      p.apply2(<<~RBS)
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
      p.apply2(<<~RBS)
        class A
          def a: () -> void
          def b: () -> void
          def c: () -> void
        end
      RBS
      p.apply2(<<~RBS)
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
      p.apply2(<<~RBS)
        class A
          def a: () -> void
          def b: () -> void
          def c: () -> void
        end
      RBS
      p.apply2(<<~RBS)
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
      p.apply2(<<~RBS)
        class A
          def a: () -> void
          def b: () -> void
          def c: () -> void
        end
      RBS
      p.apply2(<<~RBS)
        class A
          %a{patch:append_after:a}
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
      p.apply2(<<~RBS)
        class A
          def a: () -> void
          def b: () -> void
          def c: () -> void
        end
      RBS
      p.apply2(<<~RBS)
        class A
          %a{patch:prepend_before:a}
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
      p.apply2(path: Pathname("#{__dir__}/../files/a.rbs"))
      p.apply2(path: Pathname("#{__dir__}/../files/a_patch.rbs"))

      assert_equal(<<~EXPECTED, p.to_s)
        class A
          def a: (untyped) -> untyped
        end
      EXPECTED
    end

    def test_loads_from_directory
      p = RBS::Patch.new
      p.apply2(path: Pathname("#{__dir__}/../files/dir_a"))
      p.apply2(path: Pathname("#{__dir__}/../files/dir_b"))

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
      p.apply2(<<~RBS)
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
      p.apply2(<<~RBS)
        class A
          def a: () -> void
          def b: () -> void
        end
      RBS
      p.apply2(<<~RBS)
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
      p.apply2(<<~RBS)
        class A
          def a: () -> void
        end
        class B
          def b: () -> void
        end
      RBS
      p.apply2(<<~RBS)
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
      p.apply2(<<~RBS)
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
      p.apply2(<<~RBS)
        %a{patch:append_after:A}
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
        %a{patch:prepend_before:A}
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
            %a{patch:append_after:A}
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
  end
end
