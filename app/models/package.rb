class Package < ApplicationRecord
  validates_presence_of :registry_id, :name, :ecosystem
  validates_uniqueness_of :name, scope: :registry_id

  belongs_to :registry
  counter_culture :registry
  has_many :versions
  has_many :dependencies, -> { group 'package_name' }, through: :versions

  scope :ecosystem, ->(ecosystem) { where(ecosystem: Ecosystem::Base.format_name(ecosystem)) }
end
