Gem::Specification.new do |s|
  s.name               = "gis_convenience_functions"
  s.version            = "0.0.5"
  s.default_executable = "gis_convenience_functions"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Ron Mayer"]
  s.date = %q{2012-04-03}
  s.description = %q{GIS convenience functions based on Open Street Map and Census Tiger}
  s.email = %q{ramayer@gmail.com}
  s.files = ["Rakefile", "lib/gis_convenience_functions.rb", "bin/gis_convenience_functions"]
  s.test_files = ["test/test_gis_convenience_functions.rb"]
  s.homepage = %q{http://0ape.com/gis_convenience_functions}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.6.2}
  s.summary = %q{GIS convenience functions}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end

