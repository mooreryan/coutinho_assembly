require "coutinho_assembly/version"

module CoutinhoAssembly
  class Error < StandardError;
  end

  class RunnerExit
    # outputs is a hash table with info about outdirs and outfiles from the process.
    attr_accessor :proc_status, :exitstatus, :outputs

    def initialize proc_status, exitstatus, outputs
      @proc_status = proc_status
      @exitstatus  = exitstatus
      @outputs     = outputs
    end
  end

  module Runners
    module Megahit
      def log_diagnostic_files assembly_dir, assembly_prefix
        megahit_opts_fname = File.join assembly_dir, "opts.txt"
        megahit_log_fname  = File.join assembly_dir, "#{assembly_prefix}.log"

        [megahit_opts_fname, megahit_log_fname].each do |fname|
          if File.exist? fname
            contents = File.open(fname, "rt").read.chomp

            Rya::AbortIf.logger.error { contents }
          end
        end
      end

# Retries once with continue then cleans up after itself so it can be restarted with a wrapper.
      def run(exe:,

              forward_reads: nil,
              reverse_reads: nil,
              single_reads: nil,

              out_dir: nil,
              out_prefix: nil,

              num_threads: 1,
              preset: nil)

        cmd = "#{exe} " \
  "--num-cpu-threads #{num_threads} " \
  "--out-dir #{out_dir} " \
  "-1 #{forward_reads} " \
  "-2 #{reverse_reads} " \
  "-r #{single_reads}"

        # Add the optional opts

        if out_prefix
          cmd += " --out-prefix #{out_prefix}"
        end

        # For preset of 'default' or anything else, just use the megahit default.
        if preset == "meta-sensitive"
          cmd += " --presets meta-sensitive"
        elsif preset == "meta-large"
          cmd += " --presets meta-large"
        elsif preset == "fast"
          cmd += " --k-list 21"
        end

        # Run the initial assembly
        proc_status = Process.run_it cmd

        # We check if the assembly finished successfully.
        unless proc_status.exitstatus.zero?
          # The assembly failed D:
          # Try it again with continue.
          cmd += " --continue"

          # Since megahit has a checkpoint continue mode, if we can save the assembly by trying once more with --continue, it will save time.
          proc_status = Process.run_it cmd
        end

        # Now we check if the checkpoint assembly failed as well
        unless proc_status.exitstatus.zero?
          # First, we want to dump the megahit opts and log files into the log for the coutinho_assembly program.
          log_diagnostic_files out_dir, out_prefix

          # Since it failed, we want to remove the output directory, because the retry wrapper function will always fail if you try and use the same assembly directory name.
          FileUtils.rm_r out_dir if Dir.exist? out_dir

          # Now that we've got the logs and removed the outdir, the runner wrapper method can cleanly rerun this function.
        end

        outputs = {
          final_contigs: File.join(out_dir, "#{out_prefix}.contigs.fa")
        }

        # Return whichever proc_status was the last one to be set, either original assembly or the continued assembly.
        CoutinhoAssembly::RunnerExit.new proc_status, proc_status.exitstatus, outputs
      end

# Removes the intermediate contigs and zips the final contigs.  This is meant to be run on a completed assembly out dir.
      def clean_up_out_dir(zip_binary: nil,
                           assembly_dir: nil,
                           num_threads: nil)

        int_contig_dir = File.join assembly_dir, "intermediate_contigs"

        # Remove the intermediate contigs
        FileUtils.rm_r int_contig_dir if Dir.exist? int_contig_dir

        contig_glob = File.join assembly_dir, "*.contigs.fa"

        if zip_binary == "pigz"
          cmd = "#{zip_binary} -p #{num_threads} #{contig_glob}"
        else
          cmd = "#{zip_binary} #{contig_glob}"
        end

        # Zip the contigs file
        Process.run_it cmd
      end
    end

    def run_sample_seqs(exe:,
                        forward_reads:,
                        reverse_reads:,
                        single_reads:,

                        out_dir:,
                        out_prefix: nil,

                        sampling_percentage:,
                        num_subsamples:,
                        random_seed: nil)

      unless out_prefix
        # Zero pad the left for single digits.
        # TODO maybe use 3?  Will you ever take a 100% subsample?
        out_prefix = sprintf "percent_%02d", sampling_percentage
      end

      # TODO if we want to make the 1 2 or s reads optional, we'll need to NOT pass those params to this program (it doesn't handle nil inputs)
      # TODO not passing in the random seed at all yet
      cmd = "#{exe} " \
  "-1 #{forward_reads} " \
  "-2 #{reverse_reads} " \
  "-s #{single_reads} " \
  "-p #{sampling_percentage} " \
  "-n #{num_subsamples} " \
  "-o #{out_dir} " \
  "-b #{out_prefix}"

      subsample_file_names = {}

      num_subsamples.times do |sample_num|
        subsample_file_names[sample_num] = {
          forward_reads: File.join(out_dir, "#{out_prefix}.sample_#{sample_num}.1.fq"),
          reverse_reads: File.join(out_dir, "#{out_prefix}.sample_#{sample_num}.2.fq"),
          single_reads:  File.join(out_dir, "#{out_prefix}.sample_#{sample_num}.U.fq")
        }
      end

      outputs = {
        out_dir:              out_dir,
        subsample_file_names: subsample_file_names
      }

      proc_status = Process.run_it cmd

      CoutinhoAssembly::RunnerExit.new proc_status, proc_status.exitstatus, outputs
    end
  end
end
