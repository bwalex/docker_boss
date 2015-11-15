require 'docker_boss'
require 'docker_boss/helpers'
require 'net/http'

RSpec.describe DockerBoss::Helpers::MiniHTTP do
  it 'supports protocol :http' do
    req = stub_request(:get, 'http://127.0.0.1/test').
      to_return(status: 200, body: '', headers: {})

    inst = DockerBoss::Helpers::MiniHTTP.new('127.0.0.1', protocol: :http)
    inst.request(Net::HTTP::Get, '/test')

    expect(req).to have_been_requested
  end

  it 'supports protocol :https' do
    req = stub_request(:get, 'https://127.0.0.1/test').
      to_return(status: 200, body: '', headers: {})

    inst = DockerBoss::Helpers::MiniHTTP.new('127.0.0.1', protocol: :https)
    inst.request(Net::HTTP::Get, '/test')

    expect(req).to have_been_requested
  end


  let(:inst) { DockerBoss::Helpers::MiniHTTP.new('127.0.0.1') }

  context 'with query param setting' do
    it 'handles no query params' do
      req = stub_request(:get, 'http://127.0.0.1/test')

      inst.request(Net::HTTP::Get, '/test', params: {})

      expect(req).to have_been_requested
    end

    it 'handles nil query params' do
      req = stub_request(:get, 'http://127.0.0.1/test')

      inst.request(Net::HTTP::Get, '/test', params: nil)

      expect(req).to have_been_requested
    end

    it 'handles query params without value' do
      req = stub_request(:get, 'http://127.0.0.1/test?a&b&c=moo')

      inst.request(Net::HTTP::Get, '/test', params: { a: nil, b: nil, c: 'moo' })

      expect(req).to have_been_requested
    end

    it 'handles query params with value' do
      req = stub_request(:get, 'http://127.0.0.1/test?a=foo&b=bar&c=moo')

      inst.request(Net::HTTP::Get, '/test', params: { a: 'foo', b: 'bar', c: 'moo' })

      expect(req).to have_been_requested
    end

    it 'properly escapes query params' do
      req = stub_request(:get, 'http://127.0.0.1/test?a%20param=with%20spaces&a%26param=with%26ampersand')

      inst.request(Net::HTTP::Get, '/test',
                   params: { 'a param' => 'with spaces', 'a&param' => 'with&ampersand' })

      expect(req).to have_been_requested
    end
  end

  describe 'error mapping' do
    it 'throws NotFoundError on 404' do
      req = stub_request(:get, 'http://127.0.0.1/test').
        to_return(status: 404, body: '', headers: {})

      expect { inst.request(Net::HTTP::Get, '/test') }.to raise_error(DockerBoss::Helpers::MiniHTTP::NotFoundError)

      expect(req).to have_been_requested
    end
  end

  describe 'redirect handling' do
    it 'can handle a single redirect' do
      stub_request(:get, 'http://127.0.0.1/test').
        to_return(status: 301, headers: { 'Location' => '/foobar' })

      req = stub_request(:get, 'http://127.0.0.1/foobar')

      inst.request(Net::HTTP::Get, '/test')

      expect(req).to have_been_requested
    end

    it 'can handle multiple redirects' do
      stub_request(:get, 'http://127.0.0.1/test').
        to_return(status: 301, headers: { 'Location' => '/redirect_again' })
      stub_request(:get, 'http://127.0.0.1/redirect_again').
        to_return(status: 301, headers: { 'Location' => '/foobar' })

      req = stub_request(:get, 'http://127.0.0.1/foobar')

      inst.request(Net::HTTP::Get, '/test')

      expect(req).to have_been_requested
    end

    it 'fails if the redirect limit is exceeded' do
      stub_request(:get, 'http://127.0.0.1/test').
        to_return(status: 301, headers: { 'Location' => '/redirect_again' })
      stub_request(:get, 'http://127.0.0.1/redirect_again').
        to_return(status: 301, headers: { 'Location' => '/and_again' })
      stub_request(:get, 'http://127.0.0.1/and_again').
        to_return(status: 301, headers: { 'Location' => '/foobar' })

      expect { inst.request(Net::HTTP::Get, '/test') }.to raise_error(DockerBoss::Helpers::MiniHTTP::RedirectExceededError)
    end
  end
end
