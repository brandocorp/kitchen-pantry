require 'kitchen/provisioner/chef/common_sandbox'

module Kitchen
  module Provisioner
    module Chef
      class InstanceSandbox < CommonSandbox
        def populate
          prepare_json
          prepare_cache
          prepare(:data)
          prepare(
            :secret,
            type: :file,
            dest_name: "encrypted_data_bag_secret",
            key_name: :encrypted_data_bag_secret_key_path
          )
        end
      end
    end
  end
end
