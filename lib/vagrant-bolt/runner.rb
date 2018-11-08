# frozen_string_literal: true

require 'vagrant-bolt/util'

class VagrantBolt::Runner
  def initialize(env, machine, boltconfig = nil)
    @env = env
    @machine = machine
    @boltconfig = boltconfig.nil? ? machine.config.bolt : boltconfig
  end

  # Run a bolt task or plan
  # @param [Symbol, String] type The type of bolt to run; task or plan
  # @param [String] name The name of the bolt task or plan to run
  # @param [Hash] args A optional hash of bolt config overrides; {run_as: "vagrant"}. No merging will be done with the overrides
  def run(type, name, **args)
    validate_dependencies
    @boltconfig = setup_overrides(type, name, **args)
    validate
    run_bolt
  end

  private

  include VagrantBolt::Util

  # Set up config overrides
  # @param [Symbol, String] type The type of bolt to run; task or plan
  # @param [String] name The name of the bolt task or plan to run
  # @param [Hash] args A optional hash of bolt config overrides; {run_as: "vagrant"}
  # @return [Object] Bolt config with ssh info populated
  def setup_overrides(type, name, **args)
    config = @boltconfig.dup
    config.type = type
    config.name = name
    # Add any additional arguments to the config object
    config.set_options(args) unless args.nil?
    # Configure the node_list based on the config
    config.node_list ||= node_uri_list(@env, config.nodes, config.excludes)

    # Pupulate SSH and WinRM connection info
    if windows?(@machine)
      raise Vagrant::Errors::MachineGuestNotReady unless running?(@machine)

      config.node_list ||= "winrm://#{@machine.config.winrm.host}:#{@machine.config.winrm.port}"
      config.username ||= @machine.config.winrm.username
      config.ssl ||= (@machine.config.winrm.transport == :ssl)
      config.ssl_verify ||= @machine.config.winrm.ssl_peer_verification
    else
      ssh_info = @machine.ssh_info
      raise Vagrant::Errors::SSHNotReady if ssh_info.nil?

      config.node_list ||= "ssh://#{ssh_info[:host]}:#{ssh_info[:port]}"
      config.username ||= ssh_info[:username]
      config.private_key ||= ssh_info[:private_key_path][0]
      config.host_key_check ||= ssh_info[:verify_host_key]
    end
    config
  end

  # Run bolt locally with an execute
  def run_bolt
    command = create_command
    @machine.ui.info(
      I18n.t('vagrant-bolt.provisioner.bolt.info.running_bolt',
             command: command),
    )

    # TODO: Update this so it works on windows platforms
    Vagrant::Util::Subprocess.execute(
      'bash',
      '-c',
      command,
      notify: [:stdout, :stderr],
      env: { PATH: ENV["VAGRANT_OLD_ENV_PATH"] },
    ) do |io_name, data|
      if io_name == :stdout
        @machine.ui.info data
      elsif io_name == :stderr
        @machine.ui.warn data
      end
    end
  end

  # Create a bolt command from the config
  # @return [String] The bolt command
  def create_command
    # TODO: add all of the bolt the options and account for Windows Guests
    command = []
    command << @boltconfig.bolt_command
    command << "#{@boltconfig.type} run \'#{@boltconfig.name}\'"
    command << "-u \'#{@boltconfig.username}\'" unless @boltconfig.username.nil?
    command << "-p \'#{@boltconfig.password}\'" unless @boltconfig.password.nil?

    if windows?(@machine)
      ssl = (@boltconfig.ssl == true) ? "--ssl" : "--no-ssl"
      command << ssl
      ssl_verify = (@boltconfig.ssl_verify == true) ? "--ssl-verify" : "--no-ssl-verify"
      command << ssl_verify
    else
      command << "--private-key \'#{@boltconfig.private_key}\'" unless @boltconfig.private_key.nil?
      host_key_check = (@boltconfig.host_key_check == true) ? "--host-key-check" : "--no-host-key-check"
      command << host_key_check
      command << "--sudo-password \'#{@boltconfig.sudo_password}\'" unless @boltconfig.sudo_password.nil?

    end

    command << "--run_as #{@boltconfig.run_as}" unless @boltconfig.run_as.nil?
    modulepath = %r{^/.*}.match?(@boltconfig.modulepath) ? @boltconfig.modulepath : "#{@env.root_path}/#{@boltconfig.modulepath}"
    command << "--modulepath \'#{modulepath}\'"
    command << "--tmpdir \'#{@boltconfig.tmpdir}\'" unless @boltconfig.tmpdir.nil?
    boltdir = %r{^/.*}.match?(@boltconfig.boltdir) ? @boltconfig.boltdir : "#{@env.root_path}/#{@boltconfig.boltdir}"
    command << "--boltdir \'#{boltdir}\'" unless @boltconfig.boltdir.nil?
    command << "-n \'#{@boltconfig.node_list}\'"
    command << "--params \'#{@boltconfig.parameters.to_json}\'" unless @boltconfig.parameters.nil?
    command << "--verbose" if @boltconfig.verbose
    command << "--debug" if @boltconfig.debug
    command << @boltconfig.args unless @boltconfig.args.nil?
    command.flatten.join(" ")
  end

  # Validate the config object for configuration issues
  # Print and raise an exception if errors exist
  def validate
    errors = {}
    errors.merge!(@boltconfig.validate(@machine))
    errors.merge!(validate_config)

    errors.keys.each do |key|
      errors.delete(key) if errors[key].empty?
    end

    # rubocop:disable Style/GuardClause
    if errors && !errors.empty?
      raise Vagrant::Errors::ConfigInvalid,
            errors: Vagrant::Util::TemplateRenderer.render(
              "config/validation_failed",
              errors: errors,
            )
    end
    # rubocop:enable Style/GuardClause
  end

  # Validate a bolt config object for logical errors
  def validate_config
    errors = []
    errors << I18n.t('vagrant-bolt.config.bolt.errors.type_not_specified') if @boltconfig.type.nil?
    errors << I18n.t('vagrant-bolt.config.bolt.errors.no_task_or_plan') if @boltconfig.name.nil?
    { "Bolt" => errors }
  end

  # Raise an exception if dependent machines are not online
  def validate_dependencies
    return if @boltconfig.dependencies.nil? || @boltconfig.dependencies.empty?

    @boltconfig.dependencies.each do |dep|
      # Find the machine object from the active machines
      vm = machine_by_name(@env, dep)
      # Ensure it is running
      next if !vm.nil? && running?(vm)

      @machine.ui.error(
        I18n.t('vagrant-bolt.provisioner.bolt.error.dependent_machines_offline',
               name: dep),
      )
      raise Vagrant::Errors::SSHNotReady
    end
  end
end
