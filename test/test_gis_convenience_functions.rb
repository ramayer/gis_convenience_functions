require 'test/unit'
require 'gis_convenience_functions'

class GisConvenienceFunctionsTest < Test::Unit::TestCase
  def test_english_hello
    gcf = GisConvenienceFunctions.new
    puts(gcf.cheap_reverse_geocode(30,-113))
    assert_equal "hello world", "hello world"
  end

end
