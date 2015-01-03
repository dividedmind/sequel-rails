require 'spec_helper'

describe SequelRails::Storage do
  let(:environments) do
    SequelRails.configuration.normalize_environments(
      'development' => {
        'adapter' => 'postgres',
        'owner' => (ENV['TEST_OWNER'] || ENV['USER']),
        'username' => (ENV['TEST_OWNER'] || ENV['USER']),
        'database' => 'sequel_rails_test_storage_dev',
        'host' => '127.0.0.1',
      },
      'test' => {
        'adapter' => 'postgres',
        'owner' => (ENV['TEST_OWNER'] || ENV['USER']),
        'username' => (ENV['TEST_OWNER'] || ENV['USER']),
        'database' => 'sequel_rails_test_storage_test',
        'host' => '127.0.0.1',
      },
      'remote' => {
        'adapter' => 'postgres',
        'host' => '10.0.0.1',
        'database' => 'sequel_rails_test_storage_remote',
      },
      'production' => {
        'host' => '10.0.0.1',
        'database' => 'sequel_rails_test_storage_production',
      },
      'bogus' => {},
    )
  end
  before do
    allow(SequelRails.configuration).to receive(:environments).and_return(environments)
  end
  describe '.create_all' do
    it 'creates all databases skipping ones on remote host or with no database name' do
      adapter = double(:storage_adapter)
      environments.except('remote', 'production', 'bogus').values.each do |env|
        expect(SequelRails::Storage::Postgres).to receive(:new).with(env).and_return(adapter)
      end
      expect(adapter).to receive(:create).twice
      Ammeter::OutputCapturer.capture_stdout do
        described_class.create_all
      end
    end
  end
  describe '.drop_all' do
    it 'drop all databases skipping ones on remote host or with no database name' do
      adapter = double(:storage_adapter)
      environments.except('remote', 'production', 'bogus').values.each do |env|
        expect(SequelRails::Storage::Postgres).to receive(:new).with(env).and_return(adapter)
      end
      expect(adapter).to receive(:close_connections).twice
      expect(adapter).to receive(:drop).twice
      Ammeter::OutputCapturer.capture_stdout do
        described_class.drop_all
      end
    end
  end
  describe '.create_environment' do
    it 'creates database for specified environment' do
      adapter = double(:storage_adapter)
      expect(SequelRails::Storage::Postgres).to receive(:new).with(environments['development']).and_return(adapter)
      expect(adapter).to receive(:create)
      described_class.create_environment 'development'
    end
  end
  describe '.drop_environment' do
    it 'drops database for specified environment' do
      adapter = double(:storage_adapter)
      expect(SequelRails::Storage::Postgres).to receive(:new).with(environments['development']).and_return(adapter)
      expect(adapter).to receive(:close_connections)
      expect(adapter).to receive(:drop)
      described_class.drop_environment 'development'
    end
  end
  describe '.close_all_connections' do
    it 'drops opened connections to all databases on config' do
      adapter = double(:storage_adapter)
      environments.except('production', 'bogus').values.each do |env|
        expect(SequelRails::Storage::Postgres).to receive(:new).with(env).and_return(adapter)
      end
      expect(adapter).to receive(:close_connections).exactly(3).times
      Ammeter::OutputCapturer.capture_stdout do
        described_class.close_all_connections
      end
    end
  end
  describe '.close_connections_environment' do
    it 'drops opened connections to database for specified environment' do
      adapter = double(:storage_adapter)
      expect(SequelRails::Storage::Postgres).to receive(:new).with(environments['development']).and_return(adapter)
      expect(adapter).to receive(:close_connections)
      described_class.close_connections_environment 'development'
    end
  end
  describe '.adapter_for' do
    context 'when passed a hash' do
      {
        'postgres' => SequelRails::Storage::Postgres,
        'mysql' => SequelRails::Storage::Mysql,
        'mysql2' => SequelRails::Storage::Mysql2,
        'sqlite' => SequelRails::Storage::Sqlite,
        'jdbc' => SequelRails::Storage::Jdbc,
      }.each do |adapter, klass|
        it "returns an instance of #{klass} when adapter key is #{adapter}" do
          config = { 'adapter' => adapter }
          adapter = described_class.adapter_for config
          expect(adapter).to be_instance_of klass
          expect(adapter.config).to eq config
        end

        url = "#{adapter}:///foo"

        it "returns an instance of #{klass} when url is #{url}" do
          config = { 'url' => url }
          adapter = described_class.adapter_for config
          expect(adapter).to be_instance_of klass
          expect(adapter.config).to eq config
        end
      end
      it 'raises when adapter is not valid' do
        expect do
          described_class.adapter_for('adapter' => 'unknown')
        end.to raise_error RuntimeError, 'Adapter unknown not supported (:Unknown)'
      end
    end
    context 'when passed an environment' do
      it 'returns adapter based on configured environment' do
        adapter = described_class.adapter_for :development
        expect(adapter).to be_instance_of SequelRails::Storage::Postgres
        expect(adapter.config).to eq(environments['development'])
      end
    end
  end
end
