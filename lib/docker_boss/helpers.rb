require 'yaml'
require 'erb'
require 'ostruct'
require 'socket'
require 'json'
require 'uri'

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

  class MiniHTTP
    class Error < StandardError; end
    class NotFoundError < Error; end
    class RedirectExceededError < Error; end

    attr_accessor :redirect_limit
    attr_accessor :redirect_codes

    REDIRECT_LIMIT = 3
    REDIRECT_CODES = [301, 302, 303, 307]

    def initialize(host, opts = {})
      @host = host
      @protocol = opts.fetch(:protocol, :http)
      @port = opts.fetch(:port, (@protocol == :https) ? 443 : 80)
      @no_verify = opts.fetch(:no_verify, false)
      @redirect_limit = REDIRECT_LIMIT
      @redirect_codes = REDIRECT_CODES
    end

    def connection
      @http ||=
        begin
          http = Net::HTTP.new(@host, @port)
          http.use_ssl = @protocol == :https
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE if @no_verify
          http
        end
    end

    def uri_escape(s)
      URI.escape(s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
    end

    def build_path(path, query_params)
      if query_params.nil? or query_params.empty?
        path
      else
        param_str =
          query_params.map do |k,v|
            if v.nil?
              k
            else
              "#{uri_escape(k.to_s)}=#{uri_escape(v.to_s)}"
            end
          end.join('&')
        "#{path}?#{param_str}"
      end
    end

    def do_req_with_redirect(klass, path, retries, opts = {})
      fail RedirectExceededError, "Redirect limit exceeded" if retries < 1

      headers = opts.fetch(:headers, {})
      basic_auth = opts.fetch(:basic_auth, nil)
      body = opts.fetch(:body, nil)

      req = klass.new(path)
      req.basic_auth basic_auth[:user], basic_auth[:pass] if basic_auth
      headers.each { |k,v| req.add_field(k, v) }
      req.body = body if body

      response = connection.request(req)
      if redirect_codes.map(&:to_s).include? response.code
        new_location = response['Location']
        do_req_with_redirect(klass, new_location, retries - 1, opts)
      else
        response
      end
    end

    def request(klass, path, opts = {})
      query_params = opts.fetch(:params, {})

      response = do_req_with_redirect(
        klass,
        build_path(path, query_params),
        redirect_limit,
        opts
      )

      code = response.code.to_i
      if code >= 200 and code < 300
        response
      elsif code == 404
        fail NotFoundError, "Received code 404"
      else
        fail Error, "Status code: #{code}"
      end
    end
  end

  module Mixin
    def as_json(hash)
      hash.to_json
    end

    def interface_ipv4(iface)
      ifaddr = Socket.getifaddrs.find { |i| i.name == iface and i.addr and i.addr.ipv4? }
      fail ArgumentError, "Could not retrieve IPv4 address for interface `#{iface}`" if ifaddr.nil?

      ifaddr.addr.ip_address
    end

    def interface_ipv6(iface)
      # prefer routable address over link-local
      ifaddr = Socket.getifaddrs.select { |i| i.name == iface and i.addr and i.addr.ipv6? }.sort_by { |i| i.addr.ipv6_linklocal? ? 1 : 0 }.first
      fail ArgumentError, "Could not retrieve IPv6 address for interface `#{iface}`" if ifaddr.nil?

      ifaddr.addr.ip_address
    end

    def skydns_key(*parts)
      opts = parts.pop if parts.last.is_a? Hash
      key = (opts and opts.has_key? :prefix) ? opts[:prefix] : '/skydns'
      key += '/' + parts.join('.').split('.').reverse.join('/')
    end
  end
end
