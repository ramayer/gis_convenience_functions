require 'test/unit'
require 'gis_convenience_functions'

class GisConvenienceFunctionsTest < Test::Unit::TestCase
  def test_english_hello
    gcf = GisConvenienceFunctions.new(ENV['GIS_USER'] || 'gis',
                                  ENV['GIS_DATABASE'] || 'gis',
                                  ENV['GIS_HOST'] || 'gis_db',
                                  ENV['GIS_PORT'] || '5432',
                                  ENV['GIS_PASSWORD'])

    puts(gcf.cheap_reverse_geocode(30,-113))
    assert_equal "hello world", "hello world"
  end

end
