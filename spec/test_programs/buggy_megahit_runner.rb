#!/usr/bin/env ruby
#
# Use this program to test out the program restarter with megahit.

arg_str = ARGV.join " "
program = "megahit #{arg_str}"

pid = Process.spawn "#{program}"

# Randomly kill the program about 1/2 the time.
if rand < 0.5
  Process.kill "SIGKILL", pid

  # Give it a fake bad exit code
  exit 121
end

_, proc_status = Process.wait2

# Give it the actual exit code of the program (it may fail)
exit proc_status.exitstatus
