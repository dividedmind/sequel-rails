require 'English'

module SequelRails
  module Storage
    class Abstract
      attr_reader :config

      def initialize(config)
        @config = config
      end

      def create
        res = _create
        warn "[sequel] Created database '#{database}'" if res
        res
      end

      def drop
        ::Sequel::Model.db.disconnect
        res = _drop
        warn "[sequel] Dropped database '#{database}'" if res
        res
      end

      def dump(filename)
        res = _dump filename
        warn "[sequel] Dumped structure of database '#{database}' to '#{filename}'" if res
        res
      end

      def load(filename)
        res = _load filename
        warn "[sequel] Loaded structure of database '#{database}' from '#{filename}'" if res
        res
      end

      # To be overriden by subclasses
      def close_connections
        true
      end

      def database
        @database ||= config['database'] || config['path']
      end

      def username
        @username ||= config['username'] || config['user'] || ''
      end

      def password
        @password ||= config['password'] || ''
      end

      def host
        @host ||= config['host'] || ''
      end

      def port
        @port ||= config['port'] || ''
      end

      def owner
        @owner ||= config['owner'] || ''
      end

      def charset
        @charset ||= config['charset'] || ENV['CHARSET'] || 'utf8'
      end

      def collation
        @collation ||= config['collation'] || ENV['COLLATION']
      end

      private

      def add_option(commands, name, value)
        if value.present?
          separator = name[0, 2] == '--' ? '=' : ' '
          commands << "#{name}#{separator}#{value}"
        end
      end

      def add_flag(commands, flag)
        commands << flag
      end

      def exec(escaped_command)
        `#{escaped_command}`

        # Evaluate command status as a boolean like `system` does.
        $CHILD_STATUS.exitstatus == 0
      end

      def safe_exec(args)
        exec SequelRails::Shellwords.join(Array(args))
      end
    end
  end
end
