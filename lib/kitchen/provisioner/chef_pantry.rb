require 'kitchen'
require 'kitchen/pantry'
require 'kitchen/provisioner/chef_base'
require 'kitchen/provisioner/chef/instance_sandbox'
require 'kitchen/provisioner/chef/server_sandbox'

module Kitchen
  module Provisioner
    # @author Brandon Raabe <brandocorp@gmail.com>
    class ChefPantry < ChefBase

      kitchen_provisioner_api_version 2
      plugin_version Kitchen::VERSION

      default_config :client_rb, {}
      default_config :json_attributes, true
      default_config :pantry_zero_host, Kitchen::Pantry.local_ipaddress
      default_config :pantry_zero_port, 12358

      # (see Base#run_command)
      def run_command
        prefix_command(wrapped_shell_command)
      end

      def create_sandbox
        super
        create_instance_sandbox
        create_server_sandbox
        prepare_validation_pem
        prepare_client_rb
        upload_sandbox
      end

      private

      def wrapped_shell_command
        wrap_shell_code([base_command, *chef_client_args].join(" "))
      end

      def base_command
        sudo(config[:chef_client_path] || 'chef-client')
      end

      def chef_client_args
        level = config[:log_level]
        args = [
          "--config #{remote_path_join(config[:root_path], 'client.rb')}",
          "--log_level #{level}",
          "--no-color",
        ]

        if config[:json_attributes]
          json = remote_path_join(config[:root_path], "dna.json")
          args << "--json-attributes #{json}"
        end

        args << "--logfile #{config[:log_file]}" if config[:log_file]
        args << "--server #{pantry_zero_url}"
        args << "--profile-ruby" if config[:profile_ruby]

        args
      end

      def pantry_zero_url
        "http://#{config[:pantry_zero_host]}:#{config[:pantry_zero_port]}"
      end

      # Writes a fake (but valid) validation.pem into the sandbox directory.
      #
      # @api private
      def prepare_validation_pem
        info("Preparing validation.pem")
        debug("Creating a validation.pem")
        validation_pem = OpenSSL::PKey::RSA.new(2048).to_pem
        debug(validation_pem)

        File.open(File.join(sandbox_path, "validation.pem"), 'wb') do |file|
          file.write(validation_pem)
        end
      end

      # @see Kitchen::Provisioner::Pantry::ServerSandbox
      def create_server_sandbox
        debug("Creating server's sandbox in #{shared_sandbox_path}")
        # uploads stuff to the chef-zero server rather than copying to a dir
        sandbox = Chef::ServerSandbox.new(config, shared_sandbox_path, instance)
        sandbox.populate
      end

      # @see Kitchen::Provisioner::Pantry::ServerSandbox
      def upload_sandbox
        debug("Uploading server's sandbox in #{shared_sandbox_path}")
        # uploads stuff to the chef-zero server rather than copying to a dir
        sandbox = Chef::ServerSandbox.new(config, shared_sandbox_path, instance)
        sandbox.upload(pantry_zero_url)
      end


      def shared_sandbox_path
        File.join(
          ENV['HOME'],
          ".kitchen",
          "pantry_#{config[:pantry_zero_port]}",
        )
      end

      # @see Kitchen::Provisioner::Pantry::InstanceSandbox
      def create_instance_sandbox
        File.chmod(0755, sandbox_path)
        info("Preparing files for transfer")
        debug("Creating local sandbox in #{sandbox_path}")
        Chef::InstanceSandbox.new(config, sandbox_path, instance).populate
      end

      # @see v1.15.0 lib/kitchen/provisioner/chef_zero.rb#L206
      def prepare_client_rb
        data = default_config_rb.merge(config[:client_rb])

        info("Preparing client.rb")
        debug("Creating client.rb from #{data.inspect}")

        File.open(File.join(sandbox_path, "client.rb"), "wb") do |file|
          file.write(format_config_file(data))
        end
      end
    end
  end
end
