# frozen_string_literal: true
module Ecosystem
  class Bower < Base
    def install_command(db_package, version = nil)
      "bower install #{db_package.name}" + (version ? "##{version}" : "")
    end

    def all_package_names
      packages.keys
    end

    def recently_updated_package_names
      []
    end

    def packages
      @packages ||= begin
        packages = {}
        data = get("https://registry.bower.io/packages")

        data.each do |hash|
          packages[hash['name'].downcase] = hash.slice('name', 'url')
        end

        packages
      end
    end

    def versions_metadata(name)
      []
    end

    def fetch_package_metadata(name)
      packages[name.downcase]
    end

    def map_package_metadata(raw_package)
      bower_json = load_bower_json(raw_package) || raw_package
      {
        name: raw_package["name"],
        repository_url: raw_package["url"],
        licenses: bower_json['license'],
        keywords_array: bower_json['keywords'],
        homepage: bower_json["homepage"],
        description: bower_json["description"]
      }
    end

    def load_bower_json(mapped_package)
      return mapped_package unless mapped_package['url']
      github_name_with_owner = GithubUrlParser.parse(mapped_package['url'])
      return mapped_package unless github_name_with_owner
      get_json("https://raw.githubusercontent.com/#{github_name_with_owner}/master/bower.json") rescue {}
    end
  end
end
