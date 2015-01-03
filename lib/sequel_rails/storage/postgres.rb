module SequelRails
  module Storage
    class Postgres < Abstract
      def _create
        with_pgpassword do
          commands = ['createdb']
          add_connection_settings commands
          add_option commands, '--maintenance-db', maintenance_db
          add_option commands, '--encoding', encoding
          add_option commands, '--locale', locale
          add_option commands, '--lc-collate', collation
          add_option commands, '--lc-ctype', ctype
          add_option commands, '--template', template
          add_option commands, '--tablespace', tablespace
          add_option commands, '--owner', owner
          commands << database
          safe_exec commands
        end
      end

      def _drop
        with_pgpassword do
          commands = ['dropdb']
          add_connection_settings commands
          commands << database
          safe_exec commands
        end
      end

      def _dump(filename)
        with_pgpassword do
          commands = ['pg_dump']
          add_connection_settings commands
          add_flag commands, '-i'
          add_flag commands, '-s'
          add_flag commands, '-x'
          add_flag commands, '-O'
          add_option commands, '--file', filename
          commands << database
          safe_exec commands
        end
      end

      def _load(filename)
        with_pgpassword do
          commands = ['psql']
          add_connection_settings commands
          add_option commands, '--file', filename
          commands << database
          safe_exec commands
        end
      end

      def close_connections
        if (url = config['url'])
          db = ::Sequel.connect(url, config)
        else
          db = ::Sequel.connect(config)
        end
        # Will only work on Postgres > 8.4
        pid_column = db.server_version < 90_200 ? 'procpid' : 'pid'
        db.execute <<-SQL.gsub(/^\s{12}/, '')
          SELECT COUNT(pg_terminate_backend(#{pid_column}))
          FROM pg_stat_activity
          WHERE datname = '#{database}';
        SQL
      rescue Sequel::DatabaseDisconnectError
        # Will raise an error as it kills existing process running this
        # command. Seems to be only way to ensure *all* test connections
        # are closed
        nil
      end

      def encoding
        @encoding ||= config['encoding'] || charset
      end

      def locale
        @locale ||= config['locale'] || ''
      end

      def template
        @template ||= config['template'] || ''
      end

      def ctype
        @ctype ||= config['ctype'] || ''
      end

      def tablespace
        @tablespace ||= config['tablespace'] || ''
      end

      def maintenance_db
        @maintenance_db ||= config['maintenance_db'] || ''
      end

      private

      def with_pgpassword
        ENV['PGPASSWORD'] = password unless password.blank?
        yield
      ensure
        ENV['PGPASSWORD'] = nil unless password.blank?
      end

      def add_connection_settings(commands)
        add_option commands, '--username', username
        add_option commands, '--host', host
        add_option commands, '--port', port.to_s
      end
    end
  end
end
