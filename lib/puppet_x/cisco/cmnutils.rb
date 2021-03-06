# PuppetX::Cisco - Common utility methods used by Cisco Types/Providers
#
# November 2015
#
# Copyright (c) 2015-2016 Cisco and/or its affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module PuppetX
  module Cisco
    # PuppetX::Cisco::Utils: - Common helper methods shared by any Type/Provider
    class Utils
      require 'ipaddr'
      # Helper utility method for ip/prefix format networks.
      # For ip/prefix format '1.1.1.1/24' or '2000:123:38::34/64',
      # we need to mask the address using the prefix length so that they
      # are converted to '1.1.1.0/24' or '2000:123:38::/64'
      def self.process_network_mask(network)
        mask = network.split('/')[1]
        address = IPAddr.new(network).to_s
        network = address + '/' + mask unless mask.nil?
        network
      end

      # Helper utility for checking if arrays are overlapping in a
      # give list.
      # For ex: if the list has '2-10,32,42,44-89' and '11-33'
      # then this will fail as they overlap
      def self.fail_array_overlap(list)
        array = []
        list.each do |range, _val|
          larray = range.split(',')
          larray.each do |elem|
            if elem.include?('-')
              elema = elem.split('-').map { |d| Integer(d) }
              ele = elema[0]..elema[1]
              if (array & ele.to_a).empty?
                array << ele.to_a
                array = array.flatten
              else
                fail 'overlapping arrays not allowed'
              end
            else
              elema = []
              elema << elem.to_i
              if (array & elema).empty?
                array << elema
                array = array.flatten
              else
                fail 'overlapping arrays not allowed'
              end
            end
          end
        end
      end

      # Helper utility method for range summarization of VLAN and BD ranges
      # Input is a range string. For example: '10-20, 30, 14, 100-105, 21'
      # Output should be: '10-21,30,100-105'
      def self.range_summarize(range_str)
        ranges = []
        range_str.split(/,/).each do |elem|
          if elem =~ /\d+\s*\-\s*\d+/
            range_limits = elem.split(/\-/).map { |d| Integer(d) }
            ranges << (range_limits[0]..range_limits[1])
          else
            ranges << Integer(elem)
          end
        end
        # nrange array below will expand the ranges and get a single list
        nrange = []
        ranges.each do |item|
          # OR operations below will get rid of duplicates
          if item.class == Range
            nrange |= item.to_a
          else
            nrange |= [item]
          end
        end
        nrange.sort!
        ranges = []
        left = nrange.first
        right = nil
        nrange.each do |obj|
          if right && obj != right.succ
            # obj cannot be included in the current range, end this range
            if left != right
              ranges << Range.new(left, right)
            else
              ranges << left
            end
            left = obj # start of new range
          end
          right = obj # move right to point to obj
        end
        if left != right
          ranges << Range.new(left, right)
        else
          ranges << left
        end
        ranges.join(',').gsub('..', '-')
      end
    end # class Utils

    # PuppetX::Cisco::BgpUtil - Common BGP methods used by BGP Types/Providers
    class BgpUtils
      def self.process_asnum(asnum)
        err_msg = "BGP asnum must be either a 'String' or an" \
                  " 'Integer' object"
        fail ArgumentError, err_msg unless asnum.is_a?(Integer) ||
                                           asnum.is_a?(String)
        if asnum.is_a? String
          # Match ASDOT '1.5' or ASPLAIN '55' strings
          fail ArgumentError unless /^(\d+|\d+\.\d+)$/.match(asnum)
          asnum = dot_to_big(asnum) if /\d+\.\d+/.match(asnum)
        end
        asnum.to_i
      end

      # Convert BGP ASN ASDOT+ to ASPLAIN
      def self.dot_to_big(dot_str)
        fail ArgumentError unless dot_str.is_a? String
        return dot_str unless /\d+\.\d+/.match(dot_str)
        mask = 0b1111111111111111
        high = dot_str.to_i
        low = 0
        low_match = dot_str.match(/\.(\d+)/)
        low = low_match[1].to_i if low_match
        high_bits = (mask & high) << 16
        low_bits = mask & low
        high_bits + low_bits
      end
    end
  end
end
