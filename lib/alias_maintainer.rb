require 'celluloid'
require 'celluloid/io'

class AliasMaintainer
  def self.run(source, destination)
    new(source, destination).async.expire
  end

  include Celluloid::IO

  def initialize(source, destination)
    @source = source
    @destination = destination
    @addresses = []
    @subnet = 0

    every(10) do
      if rand(3) > 1
        @subnet = rand(10)
        Celluloid.logger.debug "Updated random subnet to #{@subnet.inspect}"
      end
    end
  end

  def expire
    Celluloid.logger.debug "Fetching records..."
    records = fetch_records

    Celluloid.logger.debug "Updating records: #{records.inspect}"
    update_addresses(records.map(&:address))

    min_ttl = records.map(&:ttl).min
    Celluloid.logger.debug "Expiring after minimum TTL of #{min_ttl.inspect} seconds"
    after(min_ttl) do
      expire
    end
  end

  def fetch_records
    (rand(1) + 3).times.map do |i|
      Record.new(@source, "192.168.#{@subnet}.#{i}", rand(7) + 3)
    end
  end

  def update_addresses(new_addresses)
    (@addresses - new_addresses).each do |address|
      Celluloid.logger.debug "Removing address: #{address.inspect}"
    end
    (new_addresses - @addresses).each do |address|
      Celluloid.logger.debug "Adding address: #{address.inspect}"
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
