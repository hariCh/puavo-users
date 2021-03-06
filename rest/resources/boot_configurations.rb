
module PuavoRest


class UnregisteredDevice < Host
  def self.ldap_base
    raise "Cannot use ldap methods on unregistered devices"
  end

  def preferred_image
    BootServer.current_image || Organisation.current(:no_cache).preferred_image
  end
end


class BootConfigurations < LdapSinatra


  get "/v3/:mac_address/boot_configuration" do

    # This resource is inconsistent with other resources in puavo-rest. It's
    # now deprecated and usage of it will be logged.
    puts "call to legacy boot_configuration route. Use /v3/boot_configurations/:mac_address in future"
    flog.warn "legacy call", {
      :route => "/v3/:mac_address/boot_configuration",
      :params  => params
    }
    boot_configuration
  end

  get "/v3/boot_configurations/:mac_address" do
    boot_configuration
  end

  post "/v3/boot_done/:hostname" do
    auth :server_auth
    host = Host.by_hostname!(params["hostname"])

    res = {
      :boot_duration => host.boot_duration,
      :hostname => host.hostname,
      :type => host.type,
    }

    flog.info "boot done", res
    json res
  end

  def boot_configuration
    auth :server_auth

    log_attrs = {
      :mac_address => params["mac_address"]
    }

    # Get Device or LtspServer
    begin
      host = Host.by_mac_address!(params["mac_address"])
    rescue NotFound => e
      log_attrs[:unregistered] = true
      # Create dummy host object for getting boot configuration for unregistered device
      host = UnregisteredDevice.new
    end


    if not log_attrs[:unregistered]
      log_attrs.merge!(host.to_hash)
      host.save_boot_time
    end

    flog.info "send boot configuration", :host => log_attrs

    host.grub_boot_configuration
  end

end
end
