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
      p.apply(<<~RBS)
        class A
          def a: () -> void
          def b: () -> void
          def c: () -> void
        end
      RBS
      p.apply(<<~RBS)
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
  end
end
