# frozen_string_literal: true

if Rails.env.test?
  require 'simplecov'

  if ENV['GITHUB_ACTIONS']
    require 'simplecov-cobertura'
    SimpleCov.command_name 'spec'
    SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
  end

  RSpec.configure do |config|
    config.expect_with :rspec do |expectations|
      expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    end

    config.mock_with :rspec do |mocks|
      mocks.verify_partial_doubles = true
    end

    config.shared_context_metadata_behavior = :apply_to_host_groups

    config.include FactoryBot::Syntax::Methods
  end

  # rubocop:disable Metrics/MethodLength
  def stub_rbac_permissions(*arr, **hsh)
    permissions = arr + hsh.to_a
    role_permissions = permissions.map do |permission, rds = []|
      RBACApiClient::Access.new(
        permission: permission,
        resource_definitions: rds.map do |rd|
          RBACApiClient::ResourceDefinition.new(
            attribute_filter: RBACApiClient::ResourceDefinitionFilter.new(rd[:attribute_filter])
          )
        end
      )
    end
    role = RBACApiClient::AccessPagination.new(data: role_permissions)
    allow(Rbac::API_CLIENT).to receive(:get_principal_access).and_return(role)
  end
  # rubocop:enable Metrics/MethodLength

  def nested_route(*parents)
    # Mock the .to_s method on each parent in the array to avoid RSpec converting it
    parents.each { |parent| allow(parent).to receive(:to_s).and_return(parent) }

    yield(parents)
  ensure # Make sure that the mock is just for the time of the HTTP request
    parents.each do |parent|
      klass = RSpec::Mocks.space.proxy_for(parent)
      klass.instance_variable_get(:@method_doubles)[:to_s].reset
    end
  end

  # Assembles object to be passed into factory
  # - adds url params into an object based on yaml entity definition in sorting and searching specs
  def factory_params(item, extra_params)
    item = item.each_with_object({}) do |(key, value), obj|
      obj[key] = value
      value.is_a?(String) && value.match(/^\$\{([a-zA-Z_]+)\}$/) do |m|
        obj[key] = extra_params[m[1].to_sym]
      end
    end

    item
  end

  def response_body_data
    response.parsed_body['data']
  end
end
