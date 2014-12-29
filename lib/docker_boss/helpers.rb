require 'yaml'
require 'erb'
require 'ostruct'
require 'json'

module DockerBoss::Helpers
  def self.render_erb(template_str, data)
    tmpl = ERB.new(template_str)
    ns = OpenStruct.new(data)
    ns.extend(TemplateHelpers)
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

  module TemplateHelpers
    def as_json(hash)
      hash.to_json
    end

    def interface_ipv4(iface)
      ipv4 = `ip addr show docker0 | grep -Po 'inet \\K[\\d.]+'`
      raise ArgumentError, "Could not retrieve IPv4 address for interface `#{iface}`" unless $? == 0
      ipv4.chomp
    end

    def interface_ipv6(iface)
      ipv6 = `ip addr show docker0 | grep -Po 'inet6 \\K[\\da-f:]+'`
      raise ArgumentError, "Could not retrieve IPv6 address for interface `#{iface}`" unless $? == 0
      ipv6.chomp
    end
  end
end
