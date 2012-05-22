#--
# This library dynamically profiles and resolves the type information
# observed at runtime and generates type annotation at the end.  It can be
# run as either a stand-alone script or as a Ruby library. 

require_relative "rubybreaker/debug"
require_relative "rubybreaker/runtime"
require_relative "rubybreaker/test"

# RubyBreaker is a dynamic instrumentation and monitoring tool that
# documents type information automatically.
module RubyBreaker

  # This constant contains the copyright information.
  COPYRIGHT = "Copyright (c) 2012 Jong-hoon (David) An. All Rights Reserved."

  # Options for RubyBreaker
  OPTIONS = {
    :debug => false,               # in debug mode?
    :verbose => false,             # in RubyBreaker.verbose mode?
    :mode => :lib,                 # bin or lib?
    :io_file => nil,               # generate input/output other than default?
    :append => true,               # append to the input file (if there is)?
    :stdout => true,               # also display on the screen?
    :rubylib => true,              # include core ruby library documentation?
    :file => nil,                  # the input Ruby program (as typed by the user)
  }

  # This array lists modules/classes that are actually instrumented with a
  # monitor.
  INSTALLED = []
  
  # Extension used by RubyBreaker for output/input
  EXTENSION = "rubybreaker"

  # This module has a set of entry points to the program and misc. methods
  # for running RubyBreaker.
  module Main

    include TypeDefs
    include Runtime

    public

    # This method is the trigger point to install a monitor in each
    # module/class.
    def self.setup()

      BREAKABLE.each do |mod|

        # Remember, RubyBreaker now supports a hybrid of Breakable and
        # Broken module. Just check if the module has already been
        # instrumented.
        unless INSTALLED.include?(mod) 
          MonitorInstaller.install_module_monitor(mod)
          INSTALLED << mod
        end

      end

      # At the end, we generate an output of the type information.
      at_exit do 
        self.output
      end

    end

    # Reads the input file if specified or exists
    def self.input()
      return unless OPTIONS[:io_file] && File.exist?(OPTIONS[:io_file])
      RubyBreaker.verbose("RubyBreaker input file exists...loading")
      eval "load \"#{OPTIONS[:io_file]}\"", TOPLEVEL_BINDING
    end

    # This method will generate the output.
    def self.output()

      RubyBreaker.verbose("Generating type documentation")

      io_exist = OPTIONS[:io_file] && File.exist?(OPTIONS[:io_file])

      # Document each module that was monitored
      INSTALLED.each { |mod| 
        str = Runtime::TypesigUnparser.unparse(mod) 
        if OPTIONS[:mode] == :lib
          print str
        end
      }

      # If this was a library mode run, exit now. 
      return if OPTIONS[:mode] == :lib

      # Append the result to the input file (or create a new file)
      open(OPTIONS[:io_file],"a") do |f|
        unless io_exist 
          f.puts "# This file is auto-generated by RubyBreaker"
          f.puts "require \"rubybreaker\""
        end
        f.print str
      end

      RubyBreaker.verbose("Done generating type documentation")
    end

    # This method will run do things in the following order:
    #
    #   * Checks to see if the user program and an input file exists
    #   * Loads the documentation for Ruby Core Library (TODO)
    #   * Reads the input type documentation if any
    #   * Reads (require's) the user program
    #
    def self.run()

      RubyBreaker.setup_logger()
      RubyBreaker.verbose("Running RubyBreaker")

      # First, take care of the program file.
      argv0 = OPTIONS[:file]
      prog_file = argv0
      prog_file = File.expand_path(prog_file)

      # It is ok to omit .rb extension. So try to see if prog_file.rb exists
      if !File.exist?(prog_file) && !File.extname(prog_file) == ".rb" 
        prog_file = "#{prog_file}.rb"
      end 

      if !File.exist?(prog_file)
        fatal("#{argv0} is an invalid file.")
        exit(1)
      end

      # Then, input/output file if specified
      if !OPTIONS[:io_file] || OPTIONS[:io_file].empty?
        OPTIONS[:io_file] = "#{File.basename(argv0, ".rb")}.#{EXTENSION}"
      end
      OPTIONS[:io_file] = File.absolute_path(OPTIONS[:io_file])

      if OPTIONS[:rubylib]
        RubyBreaker.verbose("Loading RubyBreaker's Ruby Core Library documentation")
        # Load the core library type documentation
        eval("require \"rubybreaker/rubylib\"", TOPLEVEL_BINDING)
      end

      # Read the input file first (as it might contain type documentation
      # already)
      Main.input()

      # Finally, require the program file! Let it run! Wheeee!
      eval("require '#{prog_file}'", TOPLEVEL_BINDING)

      RubyBreaker.verbose("Done running the input program")

    end

  end

  # This is the manual indicator for the program entry point. It simply
  # redirects to the monitor setup code.
  def self.monitor()
    Main.setup()
  end

end

