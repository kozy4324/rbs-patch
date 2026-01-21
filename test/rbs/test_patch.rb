# frozen_string_literal: true

require "test_helper"

module RBS
  class TestPatch < Minitest::Test
    def test_single_rbs_file_to_s
      p = RBS::Patch.new(<<~RBS)
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

    def test_merge_into_single_rbs_file
      p = RBS::Patch.new(<<~RBS)
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

    def test_override_method
      p = RBS::Patch.new(<<~RBS)
        class A
          def a: () -> void
        end
      RBS
      p.apply(<<~RBS)
        class A
          %a{override}
          def a: (untyped) -> untyped
        end
      RBS

      assert_equal(<<~EXPECTED, p.to_s)
        class A
          def a: (untyped) -> untyped
        end
      EXPECTED
    end
  end
end
