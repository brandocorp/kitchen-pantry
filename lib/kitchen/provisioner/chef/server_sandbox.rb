require 'chef/config'
require 'chef/chef_fs/parallelizer'
require 'chef/chef_fs/config'
require 'chef/chef_fs/file_pattern'
require 'chef/chef_fs/path_utils'
require 'chef/chef_fs/knife'
require 'chef/chef_fs/command_line'
require 'chef/knife/upload'
require 'kitchen/provisioner/chef/common_sandbox'

module Kitchen
  module Provisioner
    module Chef
      class ServerSandbox < CommonSandbox
        def populate
          FileUtils.mkdir_p sandbox_path
          File.chmod(0755, sandbox_path)

          prepare_cookbooks
          prepare(:data_bags)
          prepare(:environments)
          prepare(:nodes)
          prepare(:roles)
          prepare(:clients)
        end

        def upload(server_url)
          original_working_directory = Dir.pwd
          Dir.chdir sandbox_path

          # Load the dependencies for `knife upload`
          ::Chef::Knife::Upload.load_deps

          # Create and configure our uploader
          knife_upload = ::Chef::Knife::Upload.new
          knife_upload.config[:config_file] = File.join(sandbox_path, 'config.rb')
          # knife_upload.config[:chef_repo_path] = sandbox_path
          # knife_upload.config[:force] = true
          # knife_upload.config[:node_name] = 'pantry'
          knife_upload.name_args = ['/'] # all the things

          # with_chef_config do
            # create a temp key for talking to chef-zero
            client_pem = File.join(sandbox_path, 'client.pem')
            key_content = OpenSSL::PKey::RSA.new(2048).to_pem
            File.open(client_pem, 'w+') do |file|
              file.write key_content
            end

            client_rb = File.join(sandbox_path, 'config.rb')
            File.open(client_rb, 'w+') do |file|
              file.write <<-RUBY.gsub(/^\s{16,16}/, '')
                node_name "pantry"
                chef_server_url "#{server_url}"
                checksum_path "#{sandbox_path}/checksums"
                file_cache_path "#{sandbox_path}/cache"
                file_backup_path "#{sandbox_path}/backup"
                cookbook_path [
                  "#{sandbox_path}/cookbooks",
                  "#{sandbox_path}/site-cookbooks"
                ]
                data_bag_path "#{sandbox_path}/data_bags"
                environment_path "#{sandbox_path}/environments"
                node_path "#{sandbox_path}/nodes"
                role_path "#{sandbox_path}/roles"
                client_path "#{sandbox_path}/clients"
                user_path "#{sandbox_path}/users"
                validation_key "#{sandbox_path}/validation.pem"
                client_key "#{sandbox_path}/client.pem"
                treat_deprecation_warnings_as_errors false
              RUBY
            end

            # this needs to be run or we get an undefined method error
            knife_upload.configure_chef

            # use our temp key and user
            ::Chef::Log.level(:debug)
            ::Chef::Config.client_key = client_pem
            ::Chef::Config.node_name = 'pantry'

            # upload all the things
            knife_upload.run
          # end

          Dir.chdir(original_working_directory)
        end

        def with_chef_config
          # Backup the current chef config, and reset it
          chef_config_backup = ::Chef::Config.save
          ::Chef::Config.reset

          yield

          # Restore when done
          ::Chef::Config.restore(chef_config_backup)
        end
      end
    end
  end
end
