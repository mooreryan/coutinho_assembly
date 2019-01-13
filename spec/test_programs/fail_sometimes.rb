#!/usr/bin/env ruby

Signal.trap("SIGPIPE", "EXIT")

# I'm a program that exits with a failing code a certain percentage of the time.

abort "usage: #{__FILE__} chance_of_passing (e.g., 0.2)" unless ARGV.count == 1

pass_chance = ARGV[0].to_f
rand_val = rand

if rand_val <= pass_chance
  exit 0
else
  exit 1
end