require 'docker_boss'
require 'docker_boss/module/influxdb'
require 'json'

RSpec.describe DockerBoss::Module::Influxdb do
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

    # config options:
    #   use_ints
    #   user, pass
    #   database
    #   protocol

    # key thing to test is line protocol fun

    # data is array of:
    #   measurement: "foo"
    #   tags: %w{a b c}
    #   value: 1.0,
    #   timestamp: Time.now.to_i

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
    # config options:
    #   prefix (fixed, block)
    #   tags (fixed, block)
  end
end
