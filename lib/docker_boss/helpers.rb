require 'yaml'
require 'erb'
require 'ostruct'
require 'socket'
require 'json'

module DockerBoss::Helpers
  def self.render_erb(template_str, data)
    tmpl = ERB.new(template_str)
    ns = OpenStruct.new(data)
    ns.extend(Mixin)
    tmpl.result(ns.instance_eval { binding })
  end

  def self.render_erb_file(file, data)
    contents = File.read(file)
    render_erb(contents, data)
  end

  def self.hash_diff(old, new)
    changes = {
      :added => {},
      :removed => {},
      :changed => {}
    }

    new.each do |k,v|
      if old.has_key? k
        changes[:changed][k] = v if old[k] != v
      else
        changes[:added][k] = v
      end
    end

    old.each do |k,v|
      changes[:removed][k] = v unless new.has_key? k
    end

    changes
  end

  module Mixin
    def as_json(hash)
      hash.to_json
    end

    def interface_ipv4(iface)
      ifaddr = Socket::getifaddrs().select!{|i| i.name == iface && i.addr.ipv4? }.first
      raise ArgumentError, "Could not retrieve IPv4 address for interface `#{iface}`" if ifaddr.nil?

      ifaddr.addr.ip_address
    end

    def interface_ipv6(iface)
      # prefer routable address over link-local
      ifaddr = Socket::getifaddrs().select!{|i| i.name == iface && i.addr.ipv6? }.sort_by {|x| x.addr.ipv6_linklocal? ? 1 : 0 }.first
      raise ArgumentError, "Could not retrieve IPv6 address for interface `#{iface}`" if ifaddr.nil?

      ifaddr.addr.ip_address
    end
  end
end
