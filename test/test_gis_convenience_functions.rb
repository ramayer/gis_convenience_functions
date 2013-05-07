require 'test/unit'
require 'gis_convenience_functions'

class GisConvenienceFunctionsTest < Test::Unit::TestCase
  def test_english_hello
    assert_equal "hello world", GisConvenienceFunctions.hi("english")
  end

  def test_any_hello
    assert_equal "hello world", "wtf"
  end

end
