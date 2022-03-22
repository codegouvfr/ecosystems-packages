require "test_helper"

class RegistryTest < ActiveSupport::TestCase
  context 'associations' do
    should have_many(:packages)
    should have_many(:versions)
  end

  context 'validations' do
    should validate_presence_of(:url)
    should validate_presence_of(:name)
    should validate_presence_of(:ecosystem)
    should validate_uniqueness_of(:name)
    should validate_uniqueness_of(:url)
  end
end
