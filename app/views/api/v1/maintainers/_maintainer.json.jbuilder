json.extract! maintainer, :uuid, :login, :name, :email, :url, :created_at, :updated_at, :packages_count, :html_url
json.packages_url packages_api_v1_registry_maintainer_url(registry_id: maintainer.registry.name, id: maintainer.to_param)