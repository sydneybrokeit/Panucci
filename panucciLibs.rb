HDDSKUS ={
  "80GBSATA3" => "80",
  "160GBSATA3" => "160",
  "250GBSATA3" => "250",
  "320GBSATA3" => "320",
  "500GBSATA3" => "500",
  "1TBSATA3" => "1000",
  "80GBSATA2" => "80",
  "160GBSATA2" => "160",
  "250GBSATA2" => "250",
  "320GBSATA2" => "320",
  "500GBSATA2" => "500",
  "1TBSATA2" => "1000",
  "120GBSSD2" => "120",
  "250GBSSD2" => "250",
  "500GBSSD2" => "500",
  "80GBSATA2S" => "80",
  "160GBSATA2S" => "160",
  "250GBSATA2S" => "250",
  "320GBSATA2S" => "320",
  "500GBSATA2S" => "500",
  "1TBSATA2S" => "1000"
}

RAMSKUS= {
  "1GBDDR2E" => 1,
  "2GBDDR2E" => 2,
  "4GBDDR2E" => 4,
  "8GBDDR2E" => 8,
  "1GBDDR3U" => 1,
  "2GBDDR3U" => 2,
  "4GBDDR3U" => 4,
  "8GBDDR3U" => 8,
  "1GBDDR3S" => 1,
  "2GBDDR3S" => 2,
  "4GBDDR3S" => 4,
  "8GBDDR3S" => 8,
  "1GBDDR3E" => 1,
  "2GBDDR3E" => 2,
  "4GBDDR3E" => 4,
  "8GBDDR3E" => 8
}

class Order
  def computer_kit_listing
    kit_listing = self.kit_listing
    kit_listing.keys.each do |key|
      #puts key
      #puts kit_listing[key]
      #puts kit_listing[key]['components']
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
