require 'docker_boss'
require 'docker_boss/module/influxdb'
require 'json'

RSpec.describe DockerBoss::Module::Influxdb do
  before(:each) do
    Celluloid.logger = nil
    Celluloid.boot
  end

  after(:each) do
    Celluloid.shutdown
  end

  describe "do_post!" do
    before(:each) do
      @inst = DockerBoss::Module::Influxdb.build do
        protocol :http
        host '127.0.0.1'
        port 8086
        database 'db1'
        use_ints false
      end
    end

    context 'sends measurements' do
      before(:each) do
        stub_request(:post, 'http://127.0.0.1:8086/write').
          with(:query => { 'db' => 'db1', 'precision' => 's' }).
          to_return(:status => 200, :body => "", :headers => {})
      end

      it 'sends measurements without tags' do
        time = Time.now.to_i

        @inst.do_post!(
          [
            {
              measurement: 'some.float.val',
              tags: {},
              value: 1.23,
              timestamp: time
            }
          ]
        )

        expected_lines =
          [
            "some.float.val value=1.23 #{time}"
          ]

        expect(
          a_request(:post, 'http://127.0.0.1:8086/write').
            with(:query => { 'db' => 'db1', 'precision' => 's' }).
            with { |req|
              req.body.split("\n").to_set == expected_lines.to_set
            }
        ).to have_been_requested
      end

      it 'sends string and symbol measurements as strings' do
        @inst.do_post!(
          [
            {
              measurement: 'some.string',
              tags: {},
              value: 'string value',
              timestamp: 1447507267
            },
            {
              measurement: 'some.symbol',
              tags: {},
              value: :symbol,
              timestamp: 1447507267
            }
          ]
        )

        expected_lines =
          [
            'some.string value="string value" 1447507267',
            'some.symbol value="symbol" 1447507267'
          ]

        expect(
          a_request(:post, 'http://127.0.0.1:8086/write').
            with(:query => { 'db' => 'db1', 'precision' => 's' }).
            with { |req|
              req.body.split("\n").to_set == expected_lines.to_set
            }
        ).to have_been_requested
      end

      it 'sends numeric measurements as floats' do
        @inst.do_post!(
          [
            {
              measurement: 'some.float',
              tags: {},
              value: 3.0,
              timestamp: 1447507267
            },
            {
              measurement: 'some.int',
              tags: {},
              value: 3,
              timestamp: 1447507267
            }
          ]
        )

        expected_lines =
          [
            'some.float value=3.0 1447507267',
            'some.int value=3 1447507267'
          ]

        expect(
          a_request(:post, 'http://127.0.0.1:8086/write').
            with(:query => { 'db' => 'db1', 'precision' => 's' }).
            with { |req|
              req.body.split("\n").to_set == expected_lines.to_set
            }
        ).to have_been_requested
      end


      it 'sends boolean and nil measurements as booleans' do
        @inst.do_post!(
          [
            {
              measurement: 'some.nil',
              tags: {},
              value: nil,
              timestamp: 1447507267
            },
            {
              measurement: 'some.truthy',
              tags: {},
              value: true,
              timestamp: 1447507267
            },
            {
              measurement: 'some.falsy',
              tags: {},
              value: false,
              timestamp: 1447507267
            }
          ]
        )

        expected_lines =
          [
            'some.nil value=false 1447507267',
            'some.truthy value=true 1447507267',
            'some.falsy value=false 1447507267'
          ]

        expect(
          a_request(:post, 'http://127.0.0.1:8086/write').
            with(:query => { 'db' => 'db1', 'precision' => 's' }).
            with { |req|
              req.body.split("\n").to_set == expected_lines.to_set
            }
        ).to have_been_requested
      end

      it 'sends measurements with a number of tags' do
        time = Time.now.to_i

        @inst.do_post!(
          [
            {
              measurement: 'some.float.val',
              tags: { dc: 'london', server: 'foobar', rack: 'cb1', switch: 5},
              value: 1.23,
              timestamp: time
            }
          ]
        )

        expected_lines =
          [
            "some.float.val,dc=london,server=foobar,rack=cb1,switch=5 value=1.23 #{time}"
          ]

        expect(
          a_request(:post, 'http://127.0.0.1:8086/write').
            with(:query => { 'db' => 'db1', 'precision' => 's' }).
            with { |req|
              req.body.split("\n").to_set == expected_lines.to_set
            }
        ).to have_been_requested
      end

      it 'sends measurements with proper escaping' do
        @inst.do_post!(
          [
            {
              measurement: '"measurement with quotes"',
              tags: {
                'tag key with spaces' => 'tag,value,with"commas"',
                'a=b' => 'y=z'
              },
              value: 'string field\ value, only " need be quoted',
              timestamp: 1447507267
            }
          ]
        )

        expected_lines =
          [
            '"measurement\ with\ quotes",tag\ key\ with\ spaces=tag\,value\,with"commas",a\=b=y\=z value="string field\\ value, only \" need be quoted" 1447507267'
          ]

        expect(
          a_request(:post, 'http://127.0.0.1:8086/write').
            with(:query => { 'db' => 'db1', 'precision' => 's' }).
            with { |req|
              req.body.split("\n").to_set == expected_lines.to_set
            }
        ).to have_been_requested
      end
    end

    it 'handles HTTP basic auth' do
      @inst = DockerBoss::Module::Influxdb.build do
        protocol :http
        host '127.0.0.1'
        port 8086
        database 'db1'
        user 'user'
        pass 'pass'
      end

      stub_request(:post, 'http://user:pass@127.0.0.1:8086/write').
        with(:query => { 'db' => 'db1', 'precision' => 's' }).
        to_return(:status => 200, :body => "", :headers => {})

      @inst.do_post!(
        [
          {
            measurement: 'some.float.val',
            tags: { :dc => 'london' },
            value: 1.23,
            timestamp: Time.now.to_i
          }
        ]
      )

      expect(
        a_request(:post, 'http://user:pass@127.0.0.1:8086/write').
          with(:query => { 'db' => 'db1', 'precision' => 's' })
      ).to have_been_requested
    end

    it 'posts integers differently with use_ints' do
      @inst = DockerBoss::Module::Influxdb.build do
        protocol :http
        host '127.0.0.1'
        port 8086
        database 'db1'
        use_ints true
      end

      time = Time.now.to_i

      stub_request(:post, 'http://127.0.0.1:8086/write').
        with(:query => { 'db' => 'db1', 'precision' => 's' }).
        to_return(:status => 200, :body => "", :headers => {})

      @inst.do_post!(
        [
          {
            measurement: 'some.float.val',
            tags: { :dc => 'london' },
            value: 1.23,
            timestamp: time
          },
          {
            measurement: 'some.int.val',
            tags: {},
            value: 3,
            timestamp: time
          },
          {
            measurement: 'some.int.like.float.val',
            tags: { dc: 'paris', server: 'foobar'},
            value: 1.0,
            timestamp: time
          }
        ]
      )

      expected_lines =
        [
          "some.float.val,dc=london value=1.23 #{time}",
          "some.int.val value=3i #{time}",
          "some.int.like.float.val,dc=paris,server=foobar value=1.0 #{time}"
        ]

      expect(
        a_request(:post, 'http://127.0.0.1:8086/write').
          with(:query => { 'db' => 'db1', 'precision' => 's' }).
          with { |req|
            req.body.split("\n").to_set == expected_lines.to_set
          }
      ).to have_been_requested
    end
  end

  describe "sampling" do
    before(:each) do
      @container1 =
        {
          "Config" => {
              "Env" => {
                "FOO"  => "mariadb.test",
                "PATH" => "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
              }
          },
          "Id" => "id1",
          "Image" => "dc7e7b74d729c8b7ffab9ac5bc4b9a1463739e085b461b29928bf2fee1ff8303",
          "Name" => "/mariadb",
          "NetworkSettings" => {
             "IPAddress" => "172.17.0.19",
          },
          "Volumes" => {
             "/var/lib/mysql" => "/var/lib/docker/vfs/dir/1e3963ffc558c14d4b29bea89d6eafca9945500f5c80ea94b94b6e8664d5a1dc"
          }
        }

      @container2 =
        {
          "Config" => {
              "Env" => {
                 "FOO"  => "pgdb.test",
                 "PATH" => "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
              }
          },
          "Id" => "id2",
          "Image" => "aa1b1001ceca36a899559de64f115b0b20591d2465793ab728e3968e3036c7c4",
          "Name" => "/pgdb",
          "NetworkSettings" => {
             "IPAddress" => "172.17.1.23",
          },
          "Volumes" => {
          }
        }
    end

    context "with the default cgroup path" do
      before(:each) do
        allow(File).to receive(:exist?).with('/sys/fs/cgroup/blkio/docker').and_return(false)

        @inst = DockerBoss::Module::Influxdb.build do
          protocol :http
          host '127.0.0.1'
          port 8086
          database 'db1'
        end

        @inst.trigger([@container1, @container2], nil)
      end

      it "reads the correct files" do
        allow(File).to receive(:readlines).and_return([])
        expect(File).to receive(:readlines).with('/sys/fs/cgroup/memory/system.slice/docker-id1.scope/memory.stat')
        expect(File).to receive(:readlines).with('/sys/fs/cgroup/memory/system.slice/docker-id2.scope/memory.stat')
        allow(@inst).to receive(:do_post!)

        @inst.sample
      end
    end

    context "with a user-specified cgroup path" do
      before(:each) do
        allow(File).to receive(:exist?).with('/sys/dummy/blkio/docker').and_return(false)

        @inst = DockerBoss::Module::Influxdb.build do
          protocol :http
          host '127.0.0.1'
          port 8086
          database 'db1'
          cgroup_path '/sys/dummy'
        end

        @inst.trigger([@container1, @container2], nil)
      end

      it "reads the correct files" do
        allow(File).to receive(:readlines).and_return([])
        expect(File).to receive(:readlines).with('/sys/dummy/memory/system.slice/docker-id1.scope/memory.stat')
        expect(File).to receive(:readlines).with('/sys/dummy/memory/system.slice/docker-id2.scope/memory.stat')
        allow(@inst).to receive(:do_post!)

        @inst.sample
      end
    end

    it "can prefix with a static prefix" do
      @time = Time.now
      allow(Time).to receive(:now).and_return(@time)

      allow(File).to receive(:exist?).with('/sys/fs/cgroup/blkio/docker').and_return(false)

      @inst = DockerBoss::Module::Influxdb.build do
        protocol :http
        host '127.0.0.1'
        port 8086
        database 'db1'
        prefix 'foobar.'
      end

      allow(File).to receive(:readlines) { |f|
        case f
        when '/sys/fs/cgroup/memory/system.slice/docker-id1.scope/memory.stat'
          [
            'cache 2891776',
            'total_inactive_file 598016'
          ]
        when '/sys/fs/cgroup/memory/system.slice/docker-id2.scope/memory.stat'
          [
            'cache 5419124',
            'total_inactive_file 341941'
          ]
        else
          []
        end
      }

      expect(@inst).to receive(:do_post!).with(
        [
          {
            measurement: 'foobar.memory.cache',
            tags: {},
            value: 2891776,
            timestamp: @time.to_i
          },
          {
            measurement: 'foobar.memory.total_inactive_file',
            tags: {},
            value: 598016,
            timestamp: @time.to_i
          },
          {
            measurement: 'foobar.memory.cache',
            tags: {},
            value: 5419124,
            timestamp: @time.to_i
          },
          {
            measurement: 'foobar.memory.total_inactive_file',
            tags: {},
            value: 341941,
            timestamp: @time.to_i
          }
        ]
      )

      @inst.trigger([@container1, @container2], nil)
      @inst.sample
    end

    it "can prefix with a dynamic prefix" do
      @time = Time.now
      allow(Time).to receive(:now).and_return(@time)

      allow(File).to receive(:exist?).with('/sys/fs/cgroup/blkio/docker').and_return(false)

      @inst = DockerBoss::Module::Influxdb.build do
        protocol :http
        host '127.0.0.1'
        port 8086
        database 'db1'
        prefix { |c| "containers.#{c[:name]}." }
      end

      allow(File).to receive(:readlines) { |f|
        case f
        when '/sys/fs/cgroup/memory/system.slice/docker-id1.scope/memory.stat'
          [
            'cache 2891776',
            'total_inactive_file 598016'
          ]
        when '/sys/fs/cgroup/memory/system.slice/docker-id2.scope/memory.stat'
          [
            'cache 5419124',
            'total_inactive_file 341941'
          ]
        else
          []
        end
      }

      expect(@inst).to receive(:do_post!).with(
        [
          {
            measurement: 'containers.mariadb.memory.cache',
            tags: {},
            value: 2891776,
            timestamp: @time.to_i
          },
          {
            measurement: 'containers.mariadb.memory.total_inactive_file',
            tags: {},
            value: 598016,
            timestamp: @time.to_i
          },
          {
            measurement: 'containers.pgdb.memory.cache',
            tags: {},
            value: 5419124,
            timestamp: @time.to_i
          },
          {
            measurement: 'containers.pgdb.memory.total_inactive_file',
            tags: {},
            value: 341941,
            timestamp: @time.to_i
          }
        ]
      )

      @inst.trigger([@container1, @container2], nil)
      @inst.sample
    end

    it "can apply static tags" do
      @time = Time.now
      allow(Time).to receive(:now).and_return(@time)

      allow(File).to receive(:exist?).with('/sys/fs/cgroup/blkio/docker').and_return(false)

      @inst = DockerBoss::Module::Influxdb.build do
        protocol :http
        host '127.0.0.1'
        port 8086
        database 'db1'
        prefix ''
        tags dc: 'london', server: 'czb312bg'
      end

      allow(File).to receive(:readlines) { |f|
        case f
        when '/sys/fs/cgroup/memory/system.slice/docker-id1.scope/memory.stat'
          [
            'cache 2891776',
            'total_inactive_file 598016'
          ]
        when '/sys/fs/cgroup/memory/system.slice/docker-id2.scope/memory.stat'
          [
            'cache 5419124',
            'total_inactive_file 341941'
          ]
        else
          []
        end
      }

      expect(@inst).to receive(:do_post!).with(
        [
          {
            measurement: 'memory.cache',
            tags: { dc: 'london', server: 'czb312bg' },
            value: 2891776,
            timestamp: @time.to_i
          },
          {
            measurement: 'memory.total_inactive_file',
            tags: { dc: 'london', server: 'czb312bg' },
            value: 598016,
            timestamp: @time.to_i
          },
          {
            measurement: 'memory.cache',
            tags: { dc: 'london', server: 'czb312bg' },
            value: 5419124,
            timestamp: @time.to_i
          },
          {
            measurement: 'memory.total_inactive_file',
            tags: { dc: 'london', server: 'czb312bg' },
            value: 341941,
            timestamp: @time.to_i
          }
        ]
      )

      @inst.trigger([@container1, @container2], nil)
      @inst.sample
    end

    it "can apply dynamic tags" do
      @time = Time.now
      allow(Time).to receive(:now).and_return(@time)

      allow(File).to receive(:exist?).with('/sys/fs/cgroup/blkio/docker').and_return(false)

      @inst = DockerBoss::Module::Influxdb.build do
        protocol :http
        host '127.0.0.1'
        port 8086
        database 'db1'
        prefix ''
        tags do |c|
          {
            dc: 'london',
            container: c[:name],
            container_id: c[:id],
            foo: c['Config']['Env']['FOO']
          }
        end
      end

      allow(File).to receive(:readlines) { |f|
        case f
        when '/sys/fs/cgroup/memory/system.slice/docker-id1.scope/memory.stat'
          [
            'cache 2891776',
            'total_inactive_file 598016'
          ]
        when '/sys/fs/cgroup/memory/system.slice/docker-id2.scope/memory.stat'
          [
            'cache 5419124',
            'total_inactive_file 341941'
          ]
        else
          []
        end
      }

      expect(@inst).to receive(:do_post!).with(
        [
          {
            measurement: 'memory.cache',
            tags: { dc: 'london', container: 'mariadb', container_id: 'id1', foo: 'mariadb.test' },
            value: 2891776,
            timestamp: @time.to_i
          },
          {
            measurement: 'memory.total_inactive_file',
            tags: { dc: 'london', container: 'mariadb', container_id: 'id1', foo: 'mariadb.test' },
            value: 598016,
            timestamp: @time.to_i
          },
          {
            measurement: 'memory.cache',
            tags: { dc: 'london', container: 'pgdb', container_id: 'id2', foo: 'pgdb.test' },
            value: 5419124,
            timestamp: @time.to_i
          },
          {
            measurement: 'memory.total_inactive_file',
            tags: { dc: 'london', container: 'pgdb', container_id: 'id2', foo: 'pgdb.test' },
            value: 341941,
            timestamp: @time.to_i
          }
        ]
      )

      @inst.trigger([@container1, @container2], nil)
      @inst.sample
    end
  end

  describe "kv_sample" do
    it "reads the kv-format correctly" do
      expect(File).to receive(:readlines).and_return(
      [
        'cache 2891776',
        'rss 0',
        'rss_huge 0',
        'mapped_file 0',
        'writeback 0',
        'pgpgin 561673',
        'pgpgout 560967',
        'pgfault 0',
        'pgmajfault 0',
        'inactive_anon 0',
        'active_anon 0',
        'inactive_file 598016',
        'active_file 2293760',
        'unevictable 0',
        'hierarchical_memory_limit 18446744073709551615',
        'total_cache 2891776',
        'total_rss 0',
        'total_rss_huge 0',
        'total_mapped_file 0',
        'total_writeback 0',
        'total_pgpgin 561673',
        'total_pgpgout 560967',
        'total_pgfault 0',
        'total_pgmajfault 0',
        'total_inactive_anon 0',
        'total_active_anon 0',
        'total_inactive_file 598016',
        'total_active_file 2293760',
        'total_unevictable 0'
      ])

      @worker = DockerBoss::Module::Influxdb::Worker.new(OpenStruct.new(cgroup_docker: false, cgroup_path: '/sys/fs/cgroup'))

      samples = Hash[@worker.kv_sample('id1', 'memory', 'memory.stat', 'memory').to_a]

      expect(samples['memory.cache']).to eq(2891776)
      expect(samples['memory.hierarchical_memory_limit']).to eq(18446744073709551615)
      expect(samples['memory.unevictable']).to eq(0)
      expect(samples['memory.total_active_file']).to eq(2293760)
    end
  end

  describe "blkio_sample" do
    it "reads the blkio-format correctly" do
      expect(File).to receive(:readlines).and_return(
      [
        '8:32 Read 1537938411520',
        '8:32 Write 452823318528',
        '8:32 Sync 400998490112',
        '8:32 Async 1589763239936',
        '8:32 Total 1990761730048',
        '8:16 Read 159023266304',
        '8:16 Write 190663468032',
        '8:16 Sync 2811663360',
        '8:16 Async 346875070976',
        '8:16 Total 349686734336',
        '8:0 Read 61387027456',
        '8:0 Write 939119648768',
        '8:0 Sync 184031043584',
        '8:0 Async 816475632640',
        '8:0 Total 1000506676224',
        'Total 5326739022336'
      ])

      @worker = DockerBoss::Module::Influxdb::Worker.new(OpenStruct.new(cgroup_docker: false, cgroup_path: '/sys/fs/cgroup'))

      samples = Hash[@worker.blkio_sample('id1', 'blkio', 'blkio.io_serviced', 'blkio.io_serviced').to_a]
      expect(samples['blkio.io_serviced.read']).to eq(1758348705280)
      expect(samples['blkio.io_serviced.write']).to eq(1582606435328)
      expect(samples['blkio.io_serviced.sync']).to eq(587841197056)
      expect(samples['blkio.io_serviced.async']).to eq(2753113943552)
      expect(samples['blkio.io_serviced.total']).to eq(3340955140608)
    end
  end

  describe "blkio_v_sample" do
    it "reads the blkio-v-format correctly" do
      expect(File).to receive(:readlines).and_return(
      [
        '1:6 539110',
        '1:7 341913'
      ])

      @worker = DockerBoss::Module::Influxdb::Worker.new(OpenStruct.new(cgroup_docker: false, cgroup_path: '/sys/fs/cgroup'))

      samples = Hash[@worker.blkio_v_sample('id1', 'blkio', 'blkio.sectors', 'blkio.sectors').to_a]

      expect(samples['blkio.sectors']).to eq(881023)
    end
  end
end
