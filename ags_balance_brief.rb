#!/usr/bin/env ruby
#
# Ruby parser for Angelshares in your BTC/PTS wallet.
# Usage: $ ruby ags_balances.rb
#
# Donations accepted:
# - BTC 1Bzc7PatbRzXz6EAmvSuBuoWED96qy3zgc
# - PTS PcDLYukq5RtKyRCeC1Gv5VhAJh88ykzfka
#
# Copyright (C) 2014 donSchoe <donschoe@qhor.net>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.

require 'net/http'
require 'open-uri'
require 'time'

################################################################################

# input data URL, use any generated by the other scripts.
pts_url = 'http://q39.qhor.net/ags/4/pts.csv.txt'
btc_url = 'http://q39.qhor.net/ags/4/btc.csv.txt'

################################################################################

# reads the http content
pts_data = open(pts_url).read
btc_data = open(btc_url).read

# initializes variables for the script
ags_balances = Hash.new
pts_ags_daily_rates = Hash.new
btc_ags_daily_rates = Hash.new
ags_txbits = Hash.new { |hash, key| hash[key] = [] }
pts_sum = 0.0
btc_sum = 0.0
ags_rate = 0.0

# date in seconds of jan/2/2014 midnight UTC
day_break = 1388620800.0

# number of days running AGS
day_count = 0

# date of today midnight UTC
day_today = Time.new(Time.now.utc.year, Time.now.utc.month, Time.now.utc.day, 0, 0, 0, 0).utc

# parses PTS-data and calculates daily AGS/PTS rate
pts_data.lines.each do |line|

  # splits the CSV fields
  line = line.gsub(/\"/,'').split(';')

  # ignores the CSV header
  if not line[0].eql? 'BLOCK'

    # gets current transaction time in UTC
    time = Time.parse(line[1]).utc

    # switches day to next day
    while (time.to_f > day_break.to_f) do

      # saves AGS/PTS rate
      pts_ags_daily_rates[day_count] = ags_rate

      # increases daycount and resets counters
      day_count += 1
      pts_sum = 0.0
      day_break += 86400.0
    end

    # gets current transaction value in PTS
    amount = line[4].to_f

    # gets sum of donated PTS
    pts_sum += amount

    # gets current AGS/PTS rate
    ags_rate = 5000.0 / pts_sum
  end
end

# starts building JSON
puts '{'
puts '  "day_count":"' + day_count.to_s + '",'
puts '  "last_update":"' + day_today.to_s + '",'
puts '  "balances": {'

# resets counters
day_break = 1388620800.0
day_count = 0

# parses BTC-data and calculates daily AGS/BTC rate
btc_data.lines.each do |line|

  # splits the CSV fields
  line = line.gsub(/\"/,'').split(';')

  # ignores the CSV header
  if not line[0].eql? 'BLOCK'

    # gets current transaction time in UTC
    time = Time.parse(line[1]).utc

    # switches day to next day
    while (time.to_f > day_break.to_f) do

      # saves AGS/BTC rate
      btc_ags_daily_rates[day_count] = ags_rate

      # increases daycount and resets counters
      day_count += 1
      btc_sum = 0.0
      day_break += 86400.0
    end

    # gets current transaction value in BTC
    amount = line[4].to_f

    # gets sum of donated BTC
    btc_sum += amount

    # gets current AGS/BTC rate
    ags_rate = 5000.0 / btc_sum
  end
end

# resets counters
day_break = 1388620800.0
day_count = 0

# parses PTS-data and calculates all AGS balances for PTS holders
pts_data.lines.each do |line|

  # splits the CSV fields
  line = line.gsub(/\"/,'').split(';')

  # ignores the CSV header
  if not line[0].eql? 'BLOCK'

    # gets current transaction time in UTC
    time = Time.parse(line[1]).utc

    # does not parse any unconfirmed transactions of today
    if time.to_f < day_today.to_f

      # switches day to next day
      while (time.to_f > day_break.to_f) do

        # increases daycount
        day_count += 1
        day_break += 86400.0
      end

      # gets transaction data
      block = line[0].to_i
      txbits = line[2].to_s
      sender = line[3].to_s
      amount = line[4].to_f

      # stores all transactions for a sender address
      ags_txbits[sender] << txbits

      # sums up balances connected to addresses
      if ags_balances[sender].nil?
        ags_balances[sender] = pts_ags_daily_rates[day_count].to_f * amount
      else
        ags_balances[sender] += pts_ags_daily_rates[day_count].to_f * amount
      end
    end
  end
end

# resets counters
day_break = 1388620800.0
day_count = 0

# parses BTC-data and calculates all AGS balances for BTC holders
btc_data.lines.each do |line|

  # splits the CSV fields
  line = line.gsub(/\"/,'').split(';')

  # ignores the CSV header
  if not line[0].eql? 'BLOCK'

    # gets current transaction time in UTC
    time = Time.parse(line[1]).utc

    # does not parse any unconfirmed transactions of today
    if time.to_f < day_today.to_f

      # switches day to next day
      while (time.to_f > day_break.to_f) do

        # increases daycount
        day_count += 1
        day_break += 86400.0
      end

      # gets transaction data
      block = line[0].to_i
      txbits = line[2].to_s
      sender = line[3].to_s
      amount = line[4].to_f

      # stores all transactions for a sender address
      ags_txbits[sender] << txbits

      # sums up balances connected to addresses
      if ags_balances[sender].nil?
        ags_balances[sender] = btc_ags_daily_rates[day_count].to_f * amount
      else
        ags_balances[sender] += btc_ags_daily_rates[day_count].to_f * amount
      end

    end
  end
end

# sorts balances by value descending
ags_balances = ags_balances.sort_by {|key, value| value}.reverse

# writes JSON for each address
ags_balances.each do |adr, ags|
  print '    "' + adr.to_s + '":' + ags.to_f.round(8).to_s
  # finishes JSON
  if adr.eql? ags_balances.last.first
    puts ''
  else
    puts ','
  end
end

# finishes JSON
puts '  }'
puts '}'