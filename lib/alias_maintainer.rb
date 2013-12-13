require 'celluloid'
require 'celluloid/io'

class AliasMaintainer
  class FakeSource
    def initialize(domain)
      @domain = domain
      @subnet = 0
    end

    def fetch_records
      (rand(1) + 3).times.map do |i|
        Record.new(@domain, "192.168.#{@subnet}.#{i}", rand(7) + 3)
      end
    end

    def tick
      if rand(3) > 1
        @subnet = rand(10)
        Celluloid.logger.debug "Updated random subnet to #{@subnet.inspect}"
      end
    end
  end

  class ResolvSource
    def initialize(domain)
      @domain = domain
    end

    def fetch_records
      records = []
      Resolv::DNS.open do |dns|
        resources = dns.getresources @domain, Resolv::DNS::Resource::IN::A
        resources.each do |resource|
          records << Record.new(@domain, resource.address, resource.ttl)
        end
      end
      records
    end

    def tick
    end
  end

  class FakeDestination
    def initialize(domain)
      @domain = domain
    end

    def add_address(address)
      Celluloid.logger.debug "Adding address: #{address.inspect}"
    end

    def remove_address(address)
      Celluloid.logger.debug "Removing address: #{address.inspect}"
    end
  end

  def self.run(source_domain, destination_domain)
    if ENV["FAKE"] == "1"
      source = FakeSource.new(source_domain)
    else
      source = ResolvSource.new(source_domain)
    end
    destination = FakeDestination.new(destination_domain)

    new(source, destination).async.expire
  end

  include Celluloid::IO

  def initialize(source, destination)
    @source = source
    @destination = destination
    @addresses = []

    every(10) do
      @source.tick
    end
  end

  def expire
    Celluloid.logger.debug "Fetching records..."
    records = @source.fetch_records

    min_ttl = records.map(&:ttl).min

    if min_ttl
      Celluloid.logger.debug "Updating records: #{records.inspect}"
      update_addresses(records.map(&:address))

      Celluloid.logger.debug "Expiring after minimum TTL of #{min_ttl.inspect} seconds"
      after(min_ttl) do
        expire
      end
    else
      Celluloid.logger.error "No records found; this is really bad"
      after(10) do
        expire
      end
    end
  end

  def update_addresses(new_addresses)
    (@addresses - new_addresses).each do |address|
      @destination.remove_address(address)
    end
    (new_addresses - @addresses).each do |address|
      @destination.add_address(address)
    end
    @addresses = new_addresses
  end

  class Record
    def initialize(name, address, ttl)
      @name = name
      @address = address
      @ttl = ttl
    end
    attr_reader :name, :address, :ttl

    def inspect
      "#<Record #{@name} -> #{@address} after #{@ttl} seconds>"
    end
  end
end
