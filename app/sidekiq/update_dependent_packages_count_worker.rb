class UpdateDependentPackagesCountWorker
  include Sidekiq::Worker
  sidekiq_options queue: :low, lock: :until_executed

  def perform(package_id)
    # TODO noop empty whilst emptying the queue
    # Package.find_by_id(package_id).try(:update_dependent_packages_details)
  end
end