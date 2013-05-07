class GisConvenienceFunctions



  def self.hi(language)
    translator = Translator.new(language)
    translator.hi
  end
end

require 'gis_convenience_functions/osm'
require 'gis_convenience_functions/census_tiger'

