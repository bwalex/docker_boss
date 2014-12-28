# DockerBoss

DockerBoss monitors docker containers and keeps track of when a container is started, stopped, changed, etc. On such an event, DockerBoss triggers actions such as updating files, controlling other containers, updating entries in etcd, updating records in a built-in DNS server, etc.

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

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
