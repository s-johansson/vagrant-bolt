# frozen_string_literal: true

class VagrantBolt::Config::Global < Vagrant.plugin('2', :config)
  # @!attribute [rw] bolt_command
  #   @return [String] The full path to the bolt command. If not passed in, the default from PATH will be used.
  attr_accessor :bolt_command

  # @!attribute [rw] boltdir
  #   @return [String] The bolt working directory. Defaults to `.`
  attr_accessor :boltdir

  # @!attribute [rw] host_key_check
  #   @return [Boolean] If the connection should check the host key on the remote host (linux)
  attr_accessor :host_key_check

  # @!attribute [rw] modulepath
  #   @return [String] The path to the modules. Defaults to `modules`.
  attr_accessor :modulepath

  # @!attribute [rw] user
  #   @return [String] The user to authenticate on the machine.
  attr_accessor :user

  # @!attribute [rw] password
  #   @return [String] The password to authenticate on the machine.
  attr_accessor :password

  # @!attribute [rw] port
  #   @return [String] The port to connect to the machine.
  attr_accessor :port

  # @!attribute [rw] private_key
  #   @return [String] The path of the private_key to authenticate on the machine.
  attr_accessor :private_key

  # @!attribute [rw] run_as
  #   @return [String] User to run as using privilege escalation.
  attr_accessor :run_as

  # @!attribute [rw] sudo_password
  #   @return [String] The password to authenticate sudo on the machine.
  attr_accessor :sudo_password

  # @!attribute [rw] ssl
  #   @return [Boolean] If the connection should use SSL on with WinRM (Windows)
  attr_accessor :ssl

  # @!attribute [rw] ssl_verify
  #   @return [Boolean] If the connection should verify SSL on with WinRM (Windows)
  attr_accessor :ssl_verify

  # @!attribute [rw] tmpdir
  #   @return [String] The directory to upload and execute temporary files on the target
  attr_accessor :tmpdir

  def initialize
    @bolt_command   = UNSET_VALUE
    @boltdir        = UNSET_VALUE
    @host_key_check = UNSET_VALUE
    @modulepath     = UNSET_VALUE
    @password       = UNSET_VALUE
    @port           = UNSET_VALUE
    @private_key    = UNSET_VALUE
    @run_as         = UNSET_VALUE
    @ssl            = UNSET_VALUE
    @ssl_verify     = UNSET_VALUE
    @sudo_password  = UNSET_VALUE
    @tmpdir         = UNSET_VALUE
    @user           = UNSET_VALUE
  end

  def finalize!
    @bolt_command   = 'bolt' if @bolt_command == UNSET_VALUE
    @boltdir        = '.' if @boltdir == UNSET_VALUE
    @host_key_check = nil if @host_key_check == UNSET_VALUE
    @modulepath     = 'modules' if @modulepath == UNSET_VALUE
    @port           = nil if @port == UNSET_VALUE
    @password       = nil if @password == UNSET_VALUE
    @private_key    = nil if @private_key == UNSET_VALUE
    @run_as         = nil if @run_as == UNSET_VALUE
    @ssl            = nil if @ssl == UNSET_VALUE
    @ssl_verify     = nil if @ssl_verify == UNSET_VALUE
    @sudo_password  = nil if @sudo_password == UNSET_VALUE
    @tmpdir         = nil if @tmpdir == UNSET_VALUE
    @user           = nil if @user == UNSET_VALUE
  end

  def validate(_machine)
    errors = _detected_errors

    { "GlobalBolt" => errors }
  end

  # Generate a bolt inventory config hash for this config
  # @return [Hash] A bolt inventory config hash containing the configured parameters
  def inventory_config
    setting_map = {
      'ssh': [
        'user',
        'password',
        'run_as',
        'port',
        'private_key',
        'host_key_check',
        'sudo_password',
      ],
      'winrm': [
        'user',
        'password',
        'run_as',
        'ssl',
        'ssl_verify',
        'port',
      ],
    }
    configs = {}
    instance_variables_hash.each do |key, value|
      next if value.nil?

      setting_map.each do |transport, settings|
        next unless settings.include?(key)

        configs[transport.to_s] ||= {}
        configs[transport.to_s][key.tr('_', '-')] = value
      end
    end
    configs
  end
end
