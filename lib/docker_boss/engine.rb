require 'docker_boss'
require 'docker_boss/module'
require 'docker'
require 'thread'
require 'thwait'

class DockerBoss::Engine
  def initialize(options, config)
    @containers = []
    @options = options
    @config = config
    @mutex = Mutex.new
    @last_etcds
    @modules = []

    @config.each do |k,v|
      @modules << DockerBoss::ModuleManager[k].new(v)
    end
  end

  def trigger(id = nil)
    @modules.each do |mod|
      mod.trigger(@containers, id)
    end
  end

  def refresh_all
    @containers = Docker::Container.all.map { |c| xform_container(c.json) }
  end

  def refresh_and_trigger
    @mutex.synchronize {
      refresh_all
      trigger
    }
  end

  def xform_container(container)
    new_env = {}
    container['Config']['Env'].each do |env|
      (k,v) = env.split('=', 2)
      new_env[k] = v || true
    end
    container['Config']['Env'] = new_env
    container
  end

  def process_event(event)
    DockerBoss.logger.info "Processing event: #{event}"
    case event[:status]
    when 'start' # 'create' also triggers 'start'
      @mutex.synchronize {
        if @options[:incr_refresh]
          new_container = Docker::Container.get(event[:id]).json
          @containers.delete_if { |c| c['Id'] == event[:id] }
          @containers << xform_container(new_container)
        else
          refresh_all
        end
        trigger(event[:id])
      }
    when 'die' # 'destroy', 'kill', 'stop' also trigger 'die'
      @mutex.synchronize {
        if @options[:incr_refresh]
          @containers.delete_if { |c| c['Id'] == event[:id] }
        else
          refresh_all
        end
        trigger(event[:id])
      }
    when 'pause'
    when 'unpause'
    end
  end

  def event_loop
    @events = Queue.new
    threads = []
    threads << Thread.new do
      loop do
        event = @events.deq
        process_event(event)
      end
    end

    threads << Thread.new do
      loop do
        begin
          #Docker::Event.stream({}, Docker::Connection.new(Docker.url, {:nonblock => true})) do |event|
          Docker::Event.stream do |event|
            DockerBoss.logger.debug "New event on socket: #{event}"
            @events.enq({:id => event.id, :status => event.status})
          end
        rescue Docker::Error::TimeoutError
          next
        end
      end
    end

    @modules.each do |mod|
      begin
        threads << mod.run
      rescue NoMethodError
      end
    end

    ThreadsWait.new(*threads)
  end
end
