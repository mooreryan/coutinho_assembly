#!/usr/bin/env ruby

Signal.trap("SIGPIPE", "EXIT")

# I'm a program that exits with a failing code if my second argument is strictly less than the first argument.

abort "usage: #{__FILE__} pass_threshold value" unless ARGV.count == 2

pass_threshold = ARGV[0].to_i
value = ARGV[1].to_i

if value >= pass_threshold
  exit 0
else
  exit 1
end