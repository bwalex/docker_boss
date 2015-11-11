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
#
influxdb do
  protocol  :http
  host      'localhost'
  port      8086
  user      'root'
  pass      'root'
  no_verify false
  database  'db1'
  # use_ints true

  #prefix    { |c| "container.#{c[:name]}." }
  prefix 'containers.'

  tags do |c|
    {
      dc:             'paris-1',
      server:         'miau',
      container_name: c[:name],
      container_id:   c[:id]
    }
  end
  interval  90

  # allow /.*/

  cgroup_path '/sys/fs/cgroup'
end
