# DockerBoss

DockerBoss monitors Docker containers and keeps track of when a container is started, stopped, changed, etc. On such an event, DockerBoss triggers actions such as updating files, controlling other containers, updating entries in etcd, updating records in a built-in DNS server, etc.

DockerBoss has been built from the start to be completely pluggable. By default, it ships with 3 different modules:

 - templates: Allows re-rendering configuration files on e.g. a docker volume and then performing an action on either the host or a container, such as restarting, sending a signal, etc.

 - etcd: Allows inserting/removing keys in etcd depending on the currently running containers. This allows, for example, automatically updating etcd entries for a service such as SkyDNS when a container changes IP because it is restarted.

 - dns: The dns module has a very simple built-in DNS server. The DNS server's records get updated based on the container's addresses, names, environment variables, etc. The DNS server will pass through requests for zones that it is not the authoritative server for.

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

    $ docker-boss once -c /path/to/config.yml

To run in watch mode, execute:

    $ docker-boss watch -c /path/to/config.yml

By default, DockerBoss runs in the foreground. If you want to run DockerBoss as a daemon, execute:

    $ docker-boss watch -c /path/to/config.yml -D

Both modes support an optional log argument, which allows logging to stdout, syslog or a file:

    $ docker-boss watch -c /path/to/config.yml -l syslog
    $ docker-boss watch -c /path/to/config.yml -l -
    $ docker-boss watch -c /path/to/config.yml -l /var/log/docker_boss.log


## Configuration

An example configuration file with some settings for each of the bundled modules is included in `example.cfg.yml`.

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

 - `shell:<cmd>` - Execute a command inside the container in a shell
 - `shell_bg:<cmd>` - Same as `shell`, but does not wait for the result
 - `exec:<cmd>` - Execute a command inside the container without a shell
 - `exec_bg:<cmd>` - Same as `exec`, but does not wait for the result
 - `restart` - Restarts the container
 - `start` - Starts the container
 - `stop` - Stops the container
 - `pause` - Pause the container
 - `unpause` - Unpause the container
 - `kill` - Kill the container
 - `kill:<SIG>` - Send a signal, e.g. `SIGHUP`, to the container's root process

The `action` setting outside the `linked_container` setting allows running an arbitrary shell command on the host.

The `files` section allows specifying an array of `file` - `template` pairs. The file and template names themselves can contain ERB templates. These ERB templates can access information about the linked container via the `container` variable.

The templates themselves should also be ERB templates. They will be rendered with ERB, with a single variable in the namespace called `containers`, which is an array of all currently running containers.

Example configuration:

```yaml
templates:
  auto_haproxy:
    linked_container:
      name:   "front-haproxy"
      action: "kill:SIGHUP"
      # Other examples:
      # action: "shell:cat /proc/cpuinfo > /tmp/cpuinfo"
      # action: "exec:touch /tmp/foobar"
      # action: "restart"

    files:
      - file:     "<%= container['Volumes']['/etc/haproxy/proxies'] %>/proxies.cfg"
        template: "<%= container['Volumes']['/etc/haproxy/proxies'] %>/proxies.cfg.erb"

    action: "echo 'This happens on the host' > /tmp/foo.test"
```

A very simple example template file could look as follows:

```
<% containers.each do |c| %>
<%= c['Id'] %> -> <%= c['Name'] %>
<% end %>
```

### etcd

### dns

### Writing your own


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
