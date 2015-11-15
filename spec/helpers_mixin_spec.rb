require 'docker_boss'
require 'docker_boss/helpers'
require 'socket'
require 'ostruct'

RSpec.describe DockerBoss::Helpers::Mixin do
  let(:inst) { (Class.new { include DockerBoss::Helpers::Mixin }).new }

  before(:each) do
    allow(Socket).to receive(:getifaddrs).and_return(
      [
        OpenStruct.new(
          name: 'lo0',
          addr: Addrinfo.new(['AF_INET', 0, nil, '127.0.0.1'])
        ),
        OpenStruct.new(
          name: 'lo0',
          addr: Addrinfo.new(['AF_INET6', 0, nil, '::1'])
        ),
        OpenStruct.new(
          name: 'docker0',
          addr: Addrinfo.new(['AF_INET', 0, nil, '172.42.55.12'])
        ),
        OpenStruct.new(
          name: 'docker0',
          addr: Addrinfo.new(['AF_INET', 0, nil, '172.42.99.99'])
        ),
        OpenStruct.new(
          name: 'docker3',
          addr: nil
        ),
        OpenStruct.new(
          name: 'docker2',
          addr: Addrinfo.new(['AF_INET6', 0, nil, 'fe80::1c32:acff:fe79:f50d%awdl0'])
        ),
        OpenStruct.new(
          name: 'docker2',
          addr: Addrinfo.new(['AF_INET6', 0, nil, '2a00:1450:4009:800::200e'])
        ),
        OpenStruct.new(
          name: 'docker4',
          addr: Addrinfo.new(['AF_INET6', 0, nil, '2a03:2880:11:2f04:face:b00c::2'])
        ),
        OpenStruct.new(
          name: 'docker4',
          addr: Addrinfo.new(['AF_INET6', 0, nil, 'fdad:9a6d:589b::1'])
        ),
        OpenStruct.new(
          name: 'docker5',
          addr: Addrinfo.new(['AF_INET6', 0, nil, '2a03:2880:11:2f04:face:b00c::2'])
        ),
        OpenStruct.new(
          name: 'docker6',
          addr: Addrinfo.new(['AF_INET6', 0, nil, 'fe80::1c32:acff:fe79:f50d%awdl0'])
        ),
      ]
    )
  end

  describe '#skydns_key' do
    it 'supports a single part with dots' do
      k = inst.skydns_key('this.is.a.test.domain.org')
      expect(k).to eq('/skydns/org/domain/test/a/is/this')
    end

    it 'supports several parts without dots' do
      k = inst.skydns_key('subdomain', 'first', 'part', 'domain', 'org')
      expect(k).to eq('/skydns/org/domain/part/first/subdomain')
    end

    it 'supports several parts with dots' do
      k = inst.skydns_key('subdomain', 'first.part', 'domain.org')
      expect(k).to eq('/skydns/org/domain/part/first/subdomain')
    end

    context 'with a user-specified key prefix' do
      it 'supports a single part' do
        k = inst.skydns_key('test.domain.org', prefix: '/prefix')
        expect(k).to eq('/prefix/org/domain/test')
      end

      it 'supports multiple parts' do
        k = inst.skydns_key('subdomain', 'first.part', 'domain.org', prefix: '/prefix')
        expect(k).to eq('/prefix/org/domain/part/first/subdomain')
      end
    end
  end

  describe '#as_json' do
    it 'converts a hash to json' do
      h = {
        a: 'ABC',
        x: 'XYZ',
        z: %w{a b c d e f g},
        y: {
          abc: 'def'
        }
      }

      expect(inst.as_json(h)).to eq(h.to_json)
    end
  end

  describe '#interface_ipv4' do
    it 'fails if the interface does not exist' do
      expect { inst.interface_ipv4('docker1') }.to raise_error(ArgumentError)
    end

    it 'fails if the interface does not have any address' do
      expect { inst.interface_ipv4('docker3') }.to raise_error(ArgumentError)
    end

    it 'fails if the interface does not have an ipv4 address' do
      expect { inst.interface_ipv4('docker2') }.to raise_error(ArgumentError)
    end

    it 'returns the first IPv4 address of an interface' do
      expect(inst.interface_ipv4('docker0')).to eq('172.42.55.12')
    end
  end

  describe '#interface_ipv6' do
    it 'fails if the interface does not exist' do
      expect { inst.interface_ipv6('docker1') }.to raise_error(ArgumentError)
    end

    it 'fails if the interface does not have any address' do
      expect { inst.interface_ipv6('docker3') }.to raise_error(ArgumentError)
    end

    it 'fails if the interface does not have an ipv6 address' do
      expect { inst.interface_ipv6('docker0') }.to raise_error(ArgumentError)
    end

    it 'returns the first non-link-local IPv6 address' do
      expect(inst.interface_ipv6('docker2')).to eq('2a00:1450:4009:800::200e')
    end

    it 'returns a link-local IPv6 address when there is no other' do
      expect(inst.interface_ipv6('docker6')).to eq('fe80::1c32:acff:fe79:f50d%awdl0')
    end

    it 'returns the first IPv6 address' do
      expect(inst.interface_ipv6('docker4')).to eq('2a03:2880:11:2f04:face:b00c::2')
    end
  end
end
