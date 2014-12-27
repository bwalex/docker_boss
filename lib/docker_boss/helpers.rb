require 'yaml'
require 'erb'
require 'ostruct'

module DockerBoss::Helpers
  def self.render_erb(template_str, data)
    tmpl = ERB.new(template_str)
    ns = OpenStruct.new(data)
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
end
