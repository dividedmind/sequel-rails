require 'active_support/core_ext/class/attribute_accessors'
require 'sequel_rails/db_config'

module SequelRails
  mattr_accessor :configuration

  def self.setup(environment)
    configuration.connect environment
  end

  class Configuration < ActiveSupport::OrderedOptions
    def self.for(root, database_yml_hash)
      ::SequelRails.configuration ||= begin
        config = new
        config.root = root
        config.raw = database_yml_hash
        config
      end
    end

    def initialize(*)
      super
      self.root = Rails.root
      self.raw = nil
      self.logger = Rails.logger
      self.migration_dir = nil
      self.schema_dump = default_schema_dump
      self.load_database_tasks = true
      self.after_connect = nil
    end

    def environment_for(name)
      environments[name.to_s] || environments[name.to_sym]
    end

    def environments
      @environments ||= normalize_environments(raw)
    end

    def normalize_environments(raw)
      raw.reduce(
        # default config - use just the environment variable
        Hash.new normalize_repository_config({})
      ) do |normalized, environment|
        name, config = environment.first, environment.last
        normalized[name] = normalize_repository_config(config)
        normalized
      end
    end

    def connect(environment)
      normalized_config = environment_for environment

      unless (normalized_config.keys & %w(adapter url)).any?
        fail "Database not configured.\n" \
            'Please create config/database.yml or set DATABASE_URL in environment.'
      end

      if normalized_config['url']
        ::Sequel.connect normalized_config['url'], normalized_config
      else
        ::Sequel.connect normalized_config
      end.tap { after_connect.call if after_connect.respond_to?(:call) }
    end

    private

    def default_schema_dump
      !%w(test production).include? Rails.env
    end

    def normalize_repository_config(hash)
      config = DbConfig.new hash, :root => root

      config['max_connections'] = max_connections if max_connections
      config['search_path'] = search_path if search_path

      url = ENV['DATABASE_URL']
      config['url'] ||= url if url

      # create the url if neccessary
      config['url'] ||= config.url if config['adapter'] =~ /^(jdbc|do):/

      config
    end
  end
end
