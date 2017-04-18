require 'scrubdeku'

load 'config.rb'
load 'config/skus.rb'

module Scrub
  class Order
    def computer_kit_listing
      kit_listing = self.kit_listing
      kit_listing.keys.each do |key|
        hdd = ""
        ram = ""
        puts key
        puts kit_listing[key]
        puts kit_listing[key]['components']
        hdd = kit_listing[key]['components'].keys.select{ |component| HDDSKUS.include?(component)}[0]
        ram = kit_listing[key]['components'].keys.select{ |component| RAMSKUS.include?(component)}[0]
        ramQty = kit_listing[key]['components'][ram]["qtyEach"]
        totalRam = ramQty.to_i * RAMSKUS[ram]
        kit_listing[key]['spec'] = {'hdd' => HDDSKUS[hdd].to_i, 'ram' => totalRam}
	end
      return kit_listing
    end

    def display_kit
      listing = self.computer_kit_listing
      puts "Kit SKU\t\t\tRAM\t\t\tHDD"
      listing.keys.each do |key|
        puts "#{listing[key]['description']}"
        puts "#{key}\t\t#{listing[key]['spec']['ram']}\t\t#{listing[key]['spec']['hdd']}"
      end
    end
  end
end
