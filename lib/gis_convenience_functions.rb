# -*- coding: utf-8 -*-
require 'pg' 
class GisConvenienceFunctions

  def initialize(dbname,user,host,port,password)
    @@feet_per_meter = 3.28084
    @@miles_per_meter = 0.000621371
    @five_hundred_feet    = 152.4   # 500 / @@feet_per_meter # 402.336 # 1/4 mile in meters
    @one_quarter_mile     = 402.336 # 1/4 mile in meters
    @geo_pg ||= PGconn.open(:dbname => dbname,
                            :user=> user,
                            :host=> host,
                            :port=> port,
                            :password=>password)
  end

  def get_likely_cross_streets(lat,lon)
    sql = %Q{
      select * from (
        SELECT name,highway,waterway,route,
               ST_Distance(r.way,ST_Transform(ST_SetSRID(ST_MakePoint($2, $1),4326),900913)) as dist
               FROM planet_osm_line r
               WHERE way && ST_Buffer(ST_Transform(ST_SetSRID(ST_MakePoint($2,$1),4326),900913),#{@one_quarter_mile})
               ORDER BY way<->ST_Transform(ST_SetSRID(ST_MakePoint($2, $1),4326),900913) limit 100
       ) as a
      where
         (name is not null) and
         (highway is not null OR
          route is not null  OR 
          waterway is not null
         )
      order by dist limit 5;
    }
    result = @geo_pg.exec(sql,[lat,lon])
    result.to_a.map{|row| [row['name'],row['dist']]}
  end

  def closest_census_edges(lat,lon,interesting_distance=nil)
    interesting_distance ||= @five_hundred_feet
    sql = %Q{
      select * from (
        SELECT fullname,state,zipl,zipr,
               ST_Distance(ST_Transform(geom,900913),ST_Transform(ST_SetSRID(ST_MakePoint($2, $1),4326),900913)) as dist
               FROM census_tl_2012_edges
               JOIN census_ansi_state on (statefp = state_ansi)
               WHERE fullname is not null
               AND geom && ST_Transform(ST_Buffer(ST_Transform(ST_SetSRID(ST_MakePoint($2,$1),4326),900913),#{interesting_distance}),4269)
               ORDER BY geom<->ST_Transform(ST_SetSRID(ST_MakePoint($2, $1),4326),4269) limit 100
       ) as a
      where
         true
      order by dist limit 5;
    }
    result = @geo_pg.exec(sql,[lat,lon])
    result.to_a.map{|row| row.each_pair{|x,y| row.delete(x) unless y}; row.delete('geom'); row}
  end

  def cheap_reverse_geocode(lat,lon)
    likely_cross_streets = get_likely_cross_streets(lat,lon)
    cheap_geocode = likely_cross_streets.map{|nam,dist| nam}.uniq[0..1].join(" and ")
  end

  def zillow_neighborhood(lat,lon)
    sql = %Q{
        SELECT state,county,city,name,regionid
          FROM zillow_neighborhoods
         WHERE geom && ST_SetSRID(ST_MakePoint($2,$1),4326)
           AND ST_Intersects(geom,ST_SetSRID(ST_MakePoint($2,$1),4326))
    }
    result = @geo_pg.exec(sql,[lat,lon])
    result.to_a.map{|row| row.each_pair{|x,y| row.delete(x) unless y}; row.delete('way'); row}.first
  end

  def nearby_polygons(lat,lon,interesting_distance = nil)
    interesting_distance ||= @five_hundred_feet
    #  Consider "name IS NOT NULL or leisure='pitch' or sport='basketball'"
    sql = %Q{
        SELECT osm_id, name, amenity, admin_level, boundary, sport, leisure, building, operator,
               array_to_json(hstore_to_array(tags)) as json_tags,
               ST_Intersects(ST_Transform(ST_SetSRID(ST_MakePoint($2,$1),4326),900913),way) as intersects,
               ST_Distance(way,ST_Transform(ST_SetSRID(ST_MakePoint($2, $1),4326),900913)) as dist
          FROM planet_osm_polygon geom
         WHERE way && ST_Buffer(ST_Transform(ST_SetSRID(ST_MakePoint($2,$1),4326),900913),#{interesting_distance})
           AND ST_Intersects(ST_Buffer(ST_Transform(ST_SetSRID(ST_MakePoint($2,$1),4326),900913),#{interesting_distance}),way)
           AND name IS NOT NULL
           AND name != 'United States of America'
      ORDER BY dist,way_area
         LIMIT 100;
    }
    result = @geo_pg.exec(sql,[lat,lon])
    result.to_a.map{|row| row.each_pair{|x,y| row.delete(x) unless y}; row.delete('way'); row}
  end

  def nearby_osm_points(lat,lon,interesting_distance=nil)
    #  Consider "name IS NOT NULL or leisure='pitch' or sport='basketball'"
    interesting_distance ||= @five_hundred_feet
    sql = %Q{
        SELECT *,
               array_to_json(hstore_to_array(tags)) as json_tags,
               ST_Intersects(ST_Transform(ST_SetSRID(ST_MakePoint($2,$1),4326),900913),way) as intersects,
               ST_Distance(way,ST_Transform(ST_SetSRID(ST_MakePoint($2, $1),4326),900913)) as dist
          FROM planet_osm_point geom
         WHERE way && ST_Buffer(ST_Transform(ST_SetSRID(ST_MakePoint($2,$1),4326),900913),#{interesting_distance})
           AND ST_Intersects(ST_Buffer(ST_Transform(ST_SetSRID(ST_MakePoint($2,$1),4326),900913),#{interesting_distance}),way)
           AND name IS NOT NULL
      ORDER BY dist
         LIMIT 100
       ;
    }
    result = @geo_pg.exec(sql,[lat,lon])
    result.to_a.map{|row| row.each_pair{|x,y| row.delete(x) unless y}; row.delete('way'); row}
  end

  def guess_city_from_census_data(lat,lon)
    #  Consider "name IS NOT NULL or leisure='pitch' or sport='basketball'"
    sql = %Q{
       SELECT *
         FROM census_tl_2010_place
         JOIN census_ansi_state on (statefp10 = state_ansi)
        WHERE geom && ST_Transform(ST_SetSRID(ST_MakePoint($2,$1),4326),4269)
          AND ST_Intersects(geom, ST_Transform(ST_SetSRID(ST_MakePoint($2,$1),4326),4269));
    }
    result = @geo_pg.exec(sql,[lat,lon])
    result = result.to_a.map{|row| row.each_pair{|x,y| row.delete(x) unless y}; row.delete('geom'); row}.first
    return nil unless result
    return result['name10'],result['state_name'],result['state']
  end

  def nearby_osm_lines(lat,lon,interesting_distance=nil)
    interesting_distance ||= @five_hundred_feet
    sql = %Q{
        SELECT *,
               array_to_json(hstore_to_array(tags)) as json_tags,
               ST_Intersects(ST_Transform(ST_SetSRID(ST_MakePoint($2,$1),4326),900913),way) as intersects,
               ST_Distance(way,ST_Transform(ST_SetSRID(ST_MakePoint($2, $1),4326),900913)) as dist
          FROM planet_osm_line geom
         WHERE way && ST_Buffer(ST_Transform(ST_SetSRID(ST_MakePoint($2,$1),4326),900913),#{interesting_distance})
           AND ST_Intersects(ST_Buffer(ST_Transform(ST_SetSRID(ST_MakePoint($2,$1),4326),900913),#{interesting_distance}),way)
           AND name IS NOT NULL
      ORDER BY dist
         LIMIT 100
       ;
    }
    result = @geo_pg.exec(sql,[lat,lon])
    result.to_a.map{|row| row.each_pair{|x,y| row.delete(x) unless y}; row.delete('way'); row}
  end

  def get_blockgroups(lat,lon)
    sql = %Q{select state,county_name,tractce10,blkgrpce10,geoid10
               from census_tl_2010_bg10
               join census_ansi_county on    (state_ansi = statefp10 and county_ansi = countyfp10)
              where ST_Intersects(geom, ST_Transform(ST_SetSRID(ST_MakePoint($2, $1),4326),4269))
    }
    result = @geo_pg.exec(sql,[lat,lon])
    result.to_a.map{|row| row.each_pair{|x,y| row.delete(x) unless y}; row.delete('way'); row}
  end

  def nearby_landmarks(lat,lon)
    inside = []
    near   = []
    city = county = state = zip = nil

    city,state_name,state_abbr = guess_city_from_census_data(lat,lon)
    state = state_name || state_abbr

    if (zn = zillow_neighborhood(lat,lon))
      inside << "#{zn['name']} Neighborhood"
    end

    inside << city

    np = nearby_polygons(lat,lon)
    np.each{|p|
      if p['intersects'] == 't'
        state  ||= p['name'] if p['admin_level'] == '4'
        county ||= p['name'] if p['admin_level'] == '6'
        city   ||= p['name'] if p['admin_level'] == '8'
        inside << p['name']
      else
        near << [p['name'], p['dist'].to_f]
      end
    }

    ne = closest_census_edges(lat,lon)
    if ne.first 
      inside << ne.first['zipl']
      inside << ne.first['zipr']
      zip = ne.first['zipl'] || ne.first['zipr']
    end
    ne.each{|p|
      near << [p['fullname'],p['dist'].to_f]
    }

    nl = nearby_osm_lines(lat,lon)
    nl.each{|p|
      near   << [p['name'], p['dist'].to_f]
    }

    nl = nearby_osm_points(lat,lon)
    nl.each{|p|
      puts p.inspect
      near   << ["a bank"            , p['dist'].to_f] if p['amenity'] == 'bank'
      near   << ["a school"          , p['dist'].to_f] if p['amenity'] == 'school'
      near   << ["a library"         , p['dist'].to_f] if p['amenity'] == 'library'
      near   << ["a place of worship", p['dist'].to_f] if p['amenity'] == 'place of worship'
      near   << [p['name'], p['dist'].to_f]
    }

    inside.uniq!

    done_near = {}
    uniq_near = []
    near.sort_by{|n,d| d}.each{|n,d|
      next if done_near[n]
      uniq_near << [n,d]
      done_near[n] = true
    }

    english = nearby_landmarks_to_english(lat,lon,state,county,city,zip,inside,uniq_near)
    return({state:state,county:county,city:city,zip:zip,inside:inside,near:uniq_near,english:english})
  end

  def join_as_english(a)
    if a.length > 1
      last_fragment = a[-1]
      return "#{a[0..-2].join(", ")}, and #{last_fragment}"
    elsif a.length == 1
      return a.first
    else
      return nil
    end
  end

  def nearby_landmarks_to_english(lat,lon,state,county,city,zip,inside,near)
    return nil unless near.length > 0 or inside.length > 0
    near_fragments = near.map{|n,d| "#{n} (%d ft)" % [(d * @@feet_per_meter)]}
    result  = "The location %6.4f°N, %6.4f°E is" % [lat,lon]
    result += " in #{join_as_english(inside)}" if inside.length > 0
    result += "; and" if inside.length > 0 and near.length > 0
    result += " near #{join_as_english(near_fragments)}" if near.length > 0
    result += "."
    return result
  end

  def self.hi(language)
    translator = Translator.new(language)
    translator.hi
  end
end

#### TODO - Maybe later, refactor to move stuff here:
# require 'gis_convenience_functions/osm'
# require 'gis_convenience_functions/census_tiger'

