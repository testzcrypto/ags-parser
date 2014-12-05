#!/usr/bin/env ruby
#
# Check Invictus Innovations return PTS Donations at blockchain.
# Usage: ruby pts_return_check.rb 81604 0 > pts_check.txt
#
# Invictus Innovations to Return PTS Donations
# https://bitsharestalk.org/index.php?topic=11289
# PTS Returns - Anyone who hasn't gotten their return post here.
# https://bitsharestalk.org/index.php?topic=11971
#
# Donations accepted:
# - BTS address: testz
#
# Copyright (C) 2014 testz
#
#
#
# Ruby parser for Angelshares in the Protoshares Blockchain.
# Usage: $ ruby pts_chain.rb [block=35450] [header=1]
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

require 'json'
require 'csv'

################################################################################

# PTS daemon connection
@connection = 'http://x:x@127.0.0.1:7474'

# Enable/Disable debugging output.
@debug = true

# Enable/Display daily summaries and output clean CSV only.
@clean_csv = true

@donations = Hash.new

################################################################################

require 'net/http'
require 'uri'
require 'json'
 
class BitcoinRPC
  def initialize(service_url)
    @uri = URI.parse(service_url)
  end
 
  def method_missing(name, *args)
    post_body = { 'method' => name, 'params' => args, 'id' => 'jsonrpc' }.to_json
    resp = JSON.parse( http_post_request(post_body) )
    raise JSONRPCError, resp['error'] if resp['error']
    resp['result']
  end
 
  def http_post_request(post_body)
    http    = Net::HTTP.new(@uri.host, @uri.port)
    request = Net::HTTP::Post.new(@uri.request_uri)
    request.basic_auth @uri.user, @uri.password
    request.content_type = 'application/json'
    request.body = post_body
    http.request(request).body
  end
 
  class JSONRPCError < RuntimeError; end
end

@rpc = BitcoinRPC.new(@connection)

# gets block number (height) to start the script at
if ARGV[0].nil?
  # default
  blockstrt = 35450
else
  # from args
  blockstrt = ARGV[0].to_i
end

# initializes global args
@day = 1388620800
i=0

################################################################################

# script output start (CSV header)
$stdout.sync = true
$stderr.sync = true

if ARGV[1].nil?
  # default
  header = 1
else
  # from args
  header = ARGV[1].to_i
end

if header > 0
  puts "\"BLOCK\";\"DATETIME\";\"TXBITS\";\"SENDER\";\"DONATION[PTS]\";\"DAYSUM[PTS]\";\"DAYRATE[AGS/PTS]\""
end

# parses given transactions
def parse_tx(hi=nil, time=nil, tx)

  # gets raw transaction
  rawtx = @rpc.getrawtransaction(tx)

  # gets transaction JSON data
  jsontx = @rpc.decoderawtransaction(rawtx)

  # check every transaction output
  jsontx["vout"].each do |vout|

    # gets recieving address and value
    address = vout["scriptPubKey"]["addresses"]
    value = vout["value"]

    # checks addresses for being angelshares donation address
    if not address.nil?
      addr = address[0].to_s
      if @donations.has_key?(addr)
        donation = @donations[addr]

        # gets UTC timestamp
        stamp = Time.at(time.to_i).utc

        # checks each input for sender addresses
        senderhash = Hash.new
        jsontx['vin'].each do |vin|

          # parses the sender from input txid and n
          sendertx = vin['txid']
          sendernn = vin['vout']

          # gets raw transaction of the sender
          senderrawtx = @rpc.getrawtransaction(sendertx)

          # gets transaction JSON data of the sender
          senderjsontx = @rpc.decoderawtransaction(senderrawtx)

          # scan sender transaction for sender address
          senderjsontx["vout"].each do |sendervout|
            if sendervout['n'].eql? sendernn

              # gets angelshares sender address and input value
              if senderhash[sendervout['scriptPubKey']['addresses'].first.to_s].nil?
                senderhash[sendervout['scriptPubKey']['addresses'].first.to_s] = sendervout['value'].to_f
              else
                senderhash[sendervout['scriptPubKey']['addresses'].first.to_s] += sendervout['value'].to_f
              end
            end
          end
        end

        # gets donation value by each input address of the transaction
        outval = value
        presum = 0.0
        sumval = 0.0
        sumprint = 0.0
        txbits = ""
        from = ""
        senderhash.each do |key, inval|
          printval = 0.0
          sumval += inval
          if sumval <= outval
            printval = inval
          else
            printval = outval - presum
          end

          # prints donation stats if input value is above 0
          if printval > 0
            sumprint += printval
            txbits = tx[0..8].to_s
            from = key.to_s
            puts "\"" + hi.to_s + "\";\"" + stamp.to_s + "\";\"" + txbits + "\";\"" + from + "\";\"" + printval.round(8).to_s + "\";\"" + addr
          end
          presum += inval
        end
              
        if donation[:orgsum] == sumprint
          puts "+\"" + hi.to_s + "\";\"" + stamp.to_s + "\";\"" + txbits + "\";\"" + from + "\";\"" + sumprint.to_s + "\";\"" + addr
          donation[:sum] -= sumprint
          data = { :block => hi, :from => from, :txbits =>txbits, :amount => sumprint }
              donation[:history].push data
        end
      end
    else

      # debugging warning: transaction without output address
      if @debug
        $stderr.puts "!!!WARNG ADDRESS EMPTY #{vout.to_s}"
      end
    end
  end
end


CSV.foreach("pts-genesis-to-81603-sum.csv", :headers => true, :header_converters => :symbol, :converters => :all) do |row|
  @donations[row.fields[0].to_s] = Hash[row.headers[1..-1].zip(row.fields[1..-1])]
  @donations[row.fields[0].to_s][:orgsum] = @donations[row.fields[0].to_s][:sum]
  @donations[row.fields[0].to_s][:history] = Array.new
end

# starts parsing the blockchain in infinite loop
while true do
  # debugging output: loop number & start block height
  if @debug
    $stderr.puts "---DEBUG LOOP #{i}"
    $stderr.puts "---DEBUG BLOCK #{blockstrt}"
  end

  # gets current block height
  blockhigh = @rpc.getblockcount

  #reads every block by block
  (blockstrt.to_i..blockhigh.to_i).each do |hi|
    if @debug
      $stderr.puts "---DEBUG BLOCK #{hi}"
    end

    # gets block hash string
    blockhash = @rpc.getblockhash(hi)

    # gets JSON block data
    blockinfo = @rpc.getblock(blockhash)

    # gets block transactions & time
    transactions = blockinfo['tx']
    time = blockinfo['time']

    # parses transactions ...
    if not transactions.nil?
      if not transactions.size <= 1
        transactions.each do |tx|

          # ... one by one
          parse_tx(hi, time, tx)
        end
      else

        # ... only one available
        parse_tx(hi, time, transactions.first)
      end
    else

      # debugging warning: block without transactions
      if @debug
        $stderr.puts "!!!WARNG NO TRANSACTIONS IN BLOCK #{hi}"
      end
    end
  end

  # debugging output: current loop summary
  if @debug
    $stderr.puts "---DEBUG !!!"

    puts "---NOT returned"
    @donations.select { |address, vals| vals[:sum] > 0.0 }.each do |address, vals|
      puts "#{address} amount #{vals[:orgsum]}"
    end
    puts

    puts "---Returned MORE than donated"
    @donations.select { |address, vals| vals[:sum] < 0.0 }.each do |address, vals|
      puts "#{address} original amount #{vals[:orgsum]} over returned #{vals[:sum]}"
      vals[:history].each { |x| puts "    from #{x[:from]} at block #{x[:block]} amount #{x[:amount]}" }
    end
    puts

    puts "---Returned"
    @donations.select { |address, vals| vals[:sum] == 0.0 }.each do |address, vals|
      puts "#{address} amount #{vals[:orgsum]} at block #{vals[:history][0][:block]} from #{vals[:history][0][:from]}"
    end
  end

  # resets starting block height to next unparsed block
  blockstrt = blockhigh.to_i + 1
  i += 1

  # wait for new blocks to appear
  sleep(600)
end
