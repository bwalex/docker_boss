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
    # config options:
    #   prefix (fixed, block)
    #   tags (fixed, block)
  end
end
