# DockerBoss

DockerBoss monitors Docker containers and keeps track of when a container is started, stopped, changed, etc. On such an event, DockerBoss triggers actions such as updating files, controlling other containers, updating entries in etcd, registering/deregistering consul services, collecting container statistics, updating records in a built-in DNS server, etc.

DockerBoss has been built from the start to be completely pluggable. By default, it ships with 5 different modules:

 - templates: Allows re-rendering configuration files on e.g. a docker volume and then performing an action on either the host or a container, such as restarting, sending a signal, etc.

 - etcd: Allows inserting/removing keys in etcd depending on the currently running containers. This allows, for example, automatically updating etcd entries for a service such as SkyDNS when a container changes IP because it is restarted.

 - consul: Allows inserting/removing keys in consul's key-value store, as well as registering and deregistering services depending on the currently running containers.

 - dns: The dns module has a very simple built-in DNS server. The DNS server's records get updated based on the container's addresses, names, environment variables, etc. The DNS server will pass through requests for zones that it is not the authoritative server for.

 - influx: The influx module can collect statistics from per-container cgroups on a regular interval, including CPU usage, memory usage, etc, and post the data to an InfluxDB instance.

The pluggable design of DockerBoss, alongside the flexibility offered by the default modules, makes it possible to adapt DockerBoss to a large number of different use cases and scenarios, without being tied down to one particular convention as others do.


## Installation

Add this line to your application's Gemfile:

    gem 'docker_boss'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install docker_boss

This installs a binary called `docker-boss`.


## Usage

DockerBoss can run in a one-off mode, in which it only triggers actions based on the currently running containers and then exits. In addition, it can run in a continuous mode, in which it will trigger actions based on the currently running containers, but then continues to watch Docker for further events, triggering updates on any change.

To run it in one-off mode, execute:

    $ docker-boss once -c /path/to/config.rb

To run in watch mode, execute:

    $ docker-boss watch -c /path/to/config.rb

By default, DockerBoss runs in the foreground. If you want to run DockerBoss as a daemon, execute:

    $ docker-boss watch -c /path/to/config.rb -D

Both modes support an optional log argument, which allows logging to stdout, syslog or a file:

    $ docker-boss watch -c /path/to/config.rb -l syslog
    $ docker-boss watch -c /path/to/config.rb -l -
    $ docker-boss watch -c /path/to/config.rb -l /var/log/docker_boss.log


## Configuration

An example configuration file with some settings for each of the bundled modules is included in `example.cfg.rb`.

Each top-level key in the configuration file corresponds to the name of a module. All entries under that key are passed to the module for configuration of that particular module.

If, for example, a key called `etcd` exists, then the DockerBoss `etcd` module will be instantiated and configured with the settings under the `etcd` key in the configuration.

For more details about the configuration for each module, have a look at the detailed description of that module.

### Container description

Wherever templates are used in configuration settings or external template files, they are generally passed either a single container or an array of containers. Each container is a Ruby Hash, as follows:

```json
{
   "AppArmorProfile":"",
   "Args":[
      "mysqld"
   ],
   "Config":{
      "AttachStderr":true,
      "AttachStdin":false,
      "AttachStdout":true,
      "Cmd":[
         "mysqld"
      ],
      "CpuShares":0,
      "Cpuset":"",
      "Domainname":"",
      "Entrypoint":[
         "/docker-entrypoint.sh"
      ],
      "Env":{
         "MYSQL_ROOT_PASSWORD":"assbYrwVnWxP",
         "PATH":"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
         "MARIADB_MAJOR":"10.0",
         "MARIADB_VERSION":"10.0.15+maria-1~wheezy"
      },
      "ExposedPorts":{
         "3306/tcp":{

         }
      },
      "Hostname":"6b2bbdac4b6e",
      "Image":"mariadb",
      "MacAddress":"",
      "Memory":0,
      "MemorySwap":0,
      "NetworkDisabled":false,
      "OnBuild":null,
      "OpenStdin":false,
      "PortSpecs":null,
      "StdinOnce":false,
      "Tty":false,
      "User":"",
      "Volumes":{
         "/var/lib/mysql":{

         }
      },
      "WorkingDir":""
   },
   "Created":"2014-12-24T15:54:44.830878163Z",
   "Driver":"devicemapper",
   "ExecDriver":"native-0.2",
   "HostConfig":{
      "Binds":null,
      "CapAdd":null,
      "CapDrop":null,
      "ContainerIDFile":"",
      "Devices":[

      ],
      "Dns":null,
      "DnsSearch":null,
      "ExtraHosts":null,
      "IpcMode":"",
      "Links":null,
      "LxcConf":[

      ],
      "NetworkMode":"bridge",
      "PortBindings":{

      },
      "Privileged":false,
      "PublishAllPorts":false,
      "RestartPolicy":{
         "MaximumRetryCount":0,
         "Name":""
      },
      "SecurityOpt":null,
      "VolumesFrom":null
   },
   "HostnamePath":"/var/lib/docker/containers/6b2bbdac4b6e01caccf84346aff37f31740760a95d131b519de6e6e0ca6ba2d9/hostname",
   "HostsPath":"/var/lib/docker/containers/6b2bbdac4b6e01caccf84346aff37f31740760a95d131b519de6e6e0ca6ba2d9/hosts",
   "Id":"6b2bbdac4b6e01caccf84346aff37f31740760a95d131b519de6e6e0ca6ba2d9",
   "Image":"dc7e7b74d729c8b7ffab9ac5bc4b9a1463739e085b461b29928bf2fee1ff8303",
   "MountLabel":"",
   "Name":"/differentdb",
   "NetworkSettings":{
      "Bridge":"docker0",
      "Gateway":"172.17.42.1",
      "IPAddress":"172.17.0.19",
      "IPPrefixLen":16,
      "MacAddress":"02:42:ac:11:00:13",
      "PortMapping":null,
      "Ports":{
         "3306/tcp":null
      }
   },
   "Path":"/docker-entrypoint.sh",
   "ProcessLabel":"",
   "ResolvConfPath":"/var/lib/docker/containers/6b2bbdac4b6e01caccf84346aff37f31740760a95d131b519de6e6e0ca6ba2d9/resolv.conf",
   "State":{
      "Error":"",
      "ExitCode":0,
      "FinishedAt":"0001-01-01T00:00:00Z",
      "OOMKilled":false,
      "Paused":false,
      "Pid":13435,
      "Restarting":false,
      "Running":true,
      "StartedAt":"2014-12-24T15:54:45.133773245Z"
   },
   "Volumes":{
      "/var/lib/mysql":"/var/lib/docker/vfs/dir/1e3963ffc558c14d4b29bea89d6eafca9945500f5c80ea94b94b6e8664d5a1dc"
   },
   "VolumesRW":{
      "/var/lib/mysql":true
   }
}
```

## Modules

The core of DockerBoss only keeps track of changes to container state. All actions are part of modules.

### templates

The templates module allows re-rendering configuration files on e.g. docker volumes and then running actions such as restarting a container or sending a signal to the root process of the container.

Each configuration entry can have an optional linked container. The container is specified via its name. If the action(s) performed by a particular configuration entry can themselves trigger further update events, it is important to provide the `linked_container` configuration to avoid an infinite amount of events because each event's actions triggers further events.

The `linked_container` `action` setting allows performing one of the following actions on the container:

 - `container_shell <cmd>` - Execute a command inside the container in a shell
 - `container_shell <cmd>, bg: true` - Same as `shell`, but does not wait for the result
 - `container_exec <cmd>` - Execute a command inside the container without a shell
 - `container_exec <cmd>, bg: true` - Same as `exec`, but does not wait for the result
 - `container_restart` - Restarts the container
 - `container_start` - Starts the container
 - `container_stop` - Stops the container
 - `container_pause` - Pause the container
 - `container_unpause` - Unpause the container
 - `container_kill` - Kill the container
 - `container_kill signal: "SIGHUP"` - Send a signal, e.g. `SIGHUP`, to the container's root process

The `action` setting outside the `linked_container` setting allows running an arbitrary shell command on the host.

The `files` section allows specifying an array of `file` - `template` pairs. The file and template names themselves can contain ERB templates. These ERB templates can access information about the linked container via the `container` variable.

The templates themselves should also be ERB templates. They will be rendered with ERB, with a single variable in the namespace called `containers`, which is an array of all currently running containers.

Example configuration:

```ruby
templates do
  container /mydb$/ do |c,all_containers|
    file template: "#{c['Volumes']['/var/lib/mysql']}/foo.cfg.erb",
         target:   "#{c['Volumes']['/var/lib/mysql']}/foo.cfg"

    # All these actions are only executed if any of the files changes
    container_restart c['Id']
    # container_shell , bg: true
    # container_exec  , bg: true
    # container_start
    # container_stop
    # container_restart
    # container_pause
    # container_unpause
    # container_kill , signal: "SIGHUP"

    host_shell "echo 'This happens on the host' > /tmp/foo.test"
  end
end
```

A very simple example template file could look as follows:

```
<% all_containers.each do |c| %>
<%= c['Id'] %> -> <%= c['Name'] %>
<% end %>
```

### etcd

The etcd module adds/updates/removes keys in etcd based on changes to the containers. This can be used to provide dynamic settings based on the containers to other tools interfacing with etcd, such as SkyDNS and confd.

The `server` setting defines the host and port of the etcd server. SSL and basic HTTP auth are not yet supported. The `host` field is rendered as an ERB template, and has access to two helper functions, `interface_ipv4(some_intf)` and `interface_ipv6(some_intf)` which get the IPv4 or IPv6 address of a particular host interface.

The `setup` setting is a template, each line of which can manipulate keys in etcd. These key manipulations are run once when the module/DockerBoss starts, and can be used to ensure a clean slate, free of any old keys from a previous run. The `setup` template can use the `interface_ipv4` and `interface_ipv6` helpers. Each line must follow one of the following formats:

 - `ensure <key> <value>` - sets a given key in etcd to the given value.
 - `dir <key>` - creates the given key as a directory in etcd.
 - `absent <key>` - removes a given key in etcd.
 - `absent_recursive <key>` removes a key and all its children.

The `sets` setting supports any number of children, each of which is an ERB template that will be rendered for each container. The output of the template rendering must be lines of the following format:

 - `ensure <key> <value>` - ensure a key exists in etcd with the given value.

The etcd module will keep track of keys set during previous state updates, and if a key is no longer present, it will be removed from etcd.

Example configuration:

```ruby
etcd do
  host interface_ipv4('docker0')
  port 4001

  setup do
    absent '/skydns/docker', recursive: true
    absent '/vhosts', recursive: true
    absent '/http_auth/vhosts', recursive: true

    set "/skydns/docker/dockerhost/etcd", host: interface_ipv4('docker0'),
                                          port: 4001

    dir '/vhosts'
    dir '/http_auth/vhosts'
  end

  change do |c|
    # SkyDNS
    if c['Config']['Env'].has_key? 'SERVICES'
      c['Config']['Env']['SERVICES'].split(',').each do |s|
        (name,port) = s.split(':')

        set skydns_key(name), host: c['NetworkSettings']['IPAddress'],
                              port: port
      end
    elsif c['Config']['Env'].has_key? 'SERVICE_NAME'
      set skydns_key(c['Config']['Env']['SERVICE_NAME']), host: c['NetworkSettings']['IPAddress']
    else
      set skydns_key(c['Config']['Hostname'], 'docker'), host: c['NetworkSettings']['IPAddress']
      set skydns_key(c['Name'][1..-1], 'docker'), host: c['NetworkSettings']['IPAddress']
    end

    # VHosts
    c['Config']['Env'].fetch('VHOSTS', '').split(',').each do |vh|
      host = vh.split(':')[0]
      port = vh.split(':').fetch(1, 80)

      set "/vhosts/#{host}/#{c['Id']}", host: c['NetworkSettings']['IPAddress'],
                                        port: port
    end

    c['Config']['Env'].fetch('VHOSTS_AUTH', '').split(',').each do |vh|
      host = vh.split(':')[0]

      set "/http_auth/vhosts/#{host}", userlist: vh.split(':')[1],
                                       groups: vh.split(':')[2..-1]
    end
  end
end
```


### consul

```ruby
consul do
  host interface_ipv4('docker0')
  port 8500
  protocol :http
  default_tags :docker_boss

  setup do
    absent_services :docker_boss
    absent '/vhosts', recursive: true
    absent '/http_auth/vhosts', recursive: true

    dir '/vhosts'
    dir '/http_auth/vhosts'
  end

  change do |c|
    # Services
    if c['Config']['Env'].has_key? 'SERVICES'
      c['Config']['Env']['SERVICES'].split(',').each do |s|
        service c['Id'], name: name,
                         address: c['NetworkSettings']['IPAddress'],
                         port: port
      end
    elsif c['Config']['Env'].has_key? 'SERVICE_NAME'
      service c['Id'], name: c['Config']['Env']['SERVICE_NAME'],
                       address: c['NetworkSettings']['IPAddress']
    else
      service c['Id'], name: c['Config']['Hostname'],
                       address: c['NetworkSettings']['IPAddress']

      service c['Id'], name: c['Name'][1..-1],
                       address: c['NetworkSettings']['IPAddress']
    end

    # VHosts
    c['Config']['Env'].fetch('VHOSTS', '').split(',').each do |vh|
      host = vh.split(':')[0]
      port = vh.split(':').fetch(1, 80)

      set "/vhosts/#{host}/#{c['Id']}", host: c['NetworkSettings']['IPAddress'],
                                        port: port
    end

    c['Config']['Env'].fetch('VHOSTS_AUTH', '').split(',').each do |vh|
      host = vh.split(':')[0]

      set "/http_auth/vhosts/#{host}", userlist: vh.split(':')[1],
                                       groups: vh.split(':')[2..-1]
    end
  end
end
```

### dns

The DNS module starts a built-in DNS server based on `rubydns`. The DNS server can be configured to support a number of upstream DNS servers, to which queries fall through if no known record is available and it doesn't match any of the internal DNS zones. As Docker can currently only handle IPv4, no `AAAA` records are ever served for containers.

The `ttl` setting determines the `ttl` for each response, both positive and NXDOMAIN.

The `listen` setting is an array of addresses/ports on which the DNS server should listen. As with the `server.host` key for the etcd module, the `host` key is a template with access to the `interface_ipv4` and `interface_ipv6` helpers.

The `upstream` setting is an array of upstream DNS servers to which requests should be forwarded to if no record is available locally and the name is not within one of the local zones.

The `zones` setting is an array of zones for which the DNS server is authoritative. The DNS server will not forward requests in these zones to upstream DNS servers, not even if no local record is found.

The `setup` setting is a template, each line of which adds a new DNS record at setup time, independently of any containers. These records are added when the module/DockerBoss starts. Each line must follow the format of `some_host_name some_ip_address`. The `setup` template can use the `interface_ipv4` and `interface_ipv6` helpers.

The `spec` setting is an ERB template which should render out all hostnames for a given container, each on a separate line. A container can have any number of host records, even none at all (by simply not rendering out any hostname).

Example configuration:

```ruby
dns do
  ttl 5
  listen interface_ipv4('docker0'), 5300

  upstream "8.8.8.8"
  upstream "8.8.4.4"

  zone ".local"
  zone ".docker"

  setup do
    set :A, "etcd.dockerhost.docker", interface_ipv4('docker0')
    set :AAAA, "etcd.dockerhost.docker", interface_ipv6('docker0')
  end

  change do |c|
    name "#{c['Config']['Env'].fetch('SERVICE_NAME', c['Name'][1..-1])}.docker"
    name "#{c['Config']['Hostname']}.docker"
  end
end
```


### Writing your own

Writing your own module is really quite simple. You only have to provide a `trigger` method that will be called on each state change, and is passed an array of all the currently running containers, as well as the ID of the container that triggered the state change.

Additionally, you can provide a `run` method which can spawn off a long-running thread. The `run` method must return a `Thread` instance.

Here's a basic skeleton:
```ruby
require 'docker_boss'
require 'docker_boss/module'
require 'docker_boss/helpers'

class DockerBoss::Module::Foo < DockerBoss::Module::Base

  class Config
    attr_accessor :some_knob

    def initialize(block)
      # ... parse `block` using your DSL parser
      ConfigProxy.new(self).instance_eval(&block)
    end

    def ConfigProxy < ::SimpleDelegator
      include DockerBoss::Helpers::Mixin

      def some_knob(v)
        self.some_knob = v
      end
    end
  end

  def self.build(&block)
    # This is the class method called by the core of DockerBoss. It needs
    # to return a new instance, configured with `block`.
    DockerBoss::Module::Foo.new(&block)
  end

  def initialize(&block)
    @config = Config.new(block)
    DockerBoss.logger.debug "foo: Set up with config: #{config}"
  end

  # This method is optional; you should omit it unless you spawn off a
  # separate, long-running, thread.
  def run
    Thread.new do
      loop do
        sleep 10
      end
    end
  end

  def trigger(containers, trigger_id)
    DockerBoss.logger.debug "foo: State change triggered by container_id=#{trigger_id}"
    containers.each do |c|
      DockerBoss.logger.debug "foo: container: #{c['Id']}"
    end
  end
end
```

Any class extending `DockerBoss::Module::Base` is automatically registered as a module. The name of the class defines the name of the configuration key in the config yaml. For the example above, the name of the key would be `foo`. Any key under `foo` in the config yaml would be passed as `config` to the class constructor.


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
