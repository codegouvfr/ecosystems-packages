class Registry < ApplicationRecord
  validates_presence_of :name, :url, :ecosystem

  validates_uniqueness_of :name, :url

  has_many :packages
  has_many :versions, through: :packages

  def self.sync_all_recently_updated_packages_async
    all.each(&:sync_recently_updated_packages_async)
  end

  def self.sync_all_packages
    all.each(&:sync_all_packages)
  end

  def self.sync_all_missing_packages_async
    all.each(&:sync_missing_packages_async)
  end

  def to_param
    name
  end

  def versions_count
    packages.sum(:versions_count)
  end

  def all_package_names
    ecosystem_instance.all_package_names
  end

  def recently_updated_package_names
    ecosystem_instance.recently_updated_package_names.first(100)
  end

  def existing_package_names
    packages.pluck(:name)
  end

  def missing_package_names
    all_package_names - existing_package_names
  end

  def sync_all_packages
    sync_packages(all_package_names)
  end

  def sync_missing_packages
    sync_packages(missing_package_names)
  end

  def sync_recently_updated_packages
    sync_packages(recently_updated_package_names)
  end

  def sync_all_packages_async
    sync_packages_async(all_package_names)
  end

  def sync_missing_packages_async
    sync_packages_async(missing_package_names)
  end

  def sync_recently_updated_packages_async
    sync_packages_async(recently_updated_package_names)
  end

  def sync_packages(package_names)
    package_names.each do |name|
      begin
        sync_package(name)
      rescue => e
        puts "error syncing #{name} (#{ecosystem})"
        puts e.message
      end
    end
  end

  def sync_packages_async(package_names)
    SyncPackageWorker.perform_bulk(package_names.map{|name| [id, name]})
  end

  def sync_package(name)
    logger.info "Syncing #{name}"
    package_metadata = ecosystem_instance.package_metadata(name)
    return false unless package_metadata
    package_metadata[:ecosystem] = ecosystem.downcase
    versions_metadata = ecosystem_instance.versions_metadata(package_metadata)

    package = packages.find_or_initialize_by(name: package_metadata[:name])
    if package.new_record?
      package.assign_attributes(package_metadata.except(:name, :releases, :versions, :version, :dependencies, :properties, :page, :time, :download_stats))
      package.save! if package.changed?
    else
      attrs = package_metadata.except(:name, :releases, :versions, :version, :dependencies, :properties, :page, :time, :download_stats)
      package.update!(attrs)
    end

    new_versions = []
    existing_version_numbers = package.versions.pluck('number')

    versions_metadata.each do |version|
      new_versions << version.merge(package_id: package.id, created_at: Time.now, updated_at: Time.now) unless existing_version_numbers.find { |v| v == version[:number] }
    end

    if new_versions.any?
      new_versions.each_slice(100) do |s|
        Version.insert_all(s) 
      end
      
      all_deps = []
      all_versions = package.versions.includes(:dependencies)

      all_versions.each do |version|
         version
        next if version.dependencies.any?

        deps = begin
                ecosystem_instance.dependencies_metadata(name, version.number, package_metadata)
              rescue StandardError
                []
              end
        next unless deps&.any? && version.dependencies.empty?

        all_deps << deps.map do |dep|
          dep.merge(version_id: version.id)
        end
      end
      
      all_deps.flatten.each_slice(100) do |s|
        Dependency.insert_all(s) 
      end
    end

    updates = {last_synced_at: Time.zone.now}
    updates[:versions_count] = all_versions.length if all_versions
    package.update_details
    package.assign_attributes(updates)
    package.update_dependent_packages_count if package.save
    # package.update_integrities_async
    return package
  end

  def sync_package_async(name)
    SyncPackageWorker.perform_async(id, name)
  end

  def ecosystem_instance
    @ecosystem_instance ||= ecosystem_class.new(self)
  end

  def ecosystem_class
    Ecosystem::Base.find(ecosystem)
  end

  def top_percentage_for(package, field)
    return nil if package.send(field).nil? || package.send(field) == 0
    packages.where("#{field} >= ?", package.send(field) || 0).count.to_f / packages_count * 100
  end

  def top_percentage_for_json(package, json_field)
    return nil if package.repo_metadata[json_field].nil? || package.repo_metadata[json_field] == 0
    packages.where("(repo_metadata ->> '#{json_field}')::text::integer >= ?", package.repo_metadata[json_field] || 0).count.to_f / packages_count * 100
  end
end
