require 'ostruct'
require_relative 'version'

module RockBooks

  class CommandLineInterface

    attr_reader :book_set, :interactive_mode, :options


    class Command < Struct.new(:min_string, :max_string, :action); end


    class BadCommandError < RuntimeError; end


    # Help text to be used when requested by 'h' command, in case of unrecognized or nonexistent command, etc.
    HELP_TEXT = "
Command Line Switches:                    [rock-books version #{RockBooks::VERSION} at https://github.com/keithrbennett/rock_books]

-o {i,j,k,p,y}            - outputs data in inspect, JSON, pretty JSON, puts, or YAML format when not in shell mode
-s                        - run in shell mode
-v                        - verbose mode

Commands:

h[elp]                    - prints this help
jo[urnals]                - list of the journals' short names
r[eport_hash]             - generates a hash of journal names as keys, report text strings as values
w[rite_reports]           - writes reports to files in the specified input directory
q[uit]                    - exits this program (interactive shell mode only) (see also 'x')
x[it]                     - exits this program (interactive shell mode only) (see also 'q')

When in interactive shell mode:
  * use quotes for string parameters such as method names.
  * for pry commands, use prefix `%`.

"

    def initialize(options)
      @options = options
      @interactive_mode = !!(options.interactive_mode)
      load_data
    end


    def load_data
      @book_set = BookSet.from_directory(options.input_dir)
    end
    alias_method :reload, :load_data


    # Until command line option parsing is added, the only way to specify
    # verbose mode is in the environment variable MAC_WIFI_OPTS.
    def verbose_mode
      options.verbose
    end


    def print_help
      puts HELP_TEXT
    end


    # Pry will output the content of the method from which it was called.
    # This small method exists solely to reduce the amount of pry's output
    # that is not needed here.
    def run_pry
      binding.pry

      # the seemingly useless line below is needed to avoid pry's exiting
      # (see https://github.com/deivid-rodriguez/pry-byebug/issues/45)
      _a = nil
    end


    # Runs a pry session in the context of this object.
    # Commands and options specified on the command line can also be specified in the shell.
    def run_shell
      begin
        require 'pry'
      rescue LoadError
        message = "The 'pry' gem and/or one of its prerequisites, required for running the shell, was not found." +
            " Please `gem install pry` or, if necessary, `sudo gem install pry`."
        raise Error.new(message)
      end

      print_help

      # Enable the line below if you have any problems with pry configuration being loaded
      # that is messing up this runtime use of pry:
      # Pry.config.should_load_rc = false

      # Strangely, this is the only thing I have found that successfully suppresses the
      # code context output, which is not useful here. Anyway, this will differentiate
      # a pry command from a DSL command, which _is_ useful here.
      Pry.config.command_prefix = '%'

      run_pry
    end


    # Look up the command name and, if found, run it. If not, execute the passed block.
    def attempt_command_action(command, *args, &error_handler_block)
      action = find_command_action(command)

      if action
        action.(*args)
      else
        error_handler_block.call
        nil
      end
    end


    # For use by the shell when the user types the DSL commands
    def method_missing(method_name, *method_args)
      attempt_command_action(method_name.to_s, *method_args) do
        puts(%Q{"#{method_name}" is not a valid command or option. } \
          << 'If you intend for this to be a string literal, ' \
          << 'use quotes or %q{}/%Q{}.')
      end
    end


    # Processes the command (ARGV[0]) and any relevant options (ARGV[1..-1]).
    #
    # CAUTION! In interactive mode, any strings entered (e.g. a network name) MUST
    # be in a form that the Ruby interpreter will recognize as a string,
    # i.e. single or double quotes, %q, %Q, etc.
    # Otherwise it will assume it's a method name and pass it to method_missing!
    def process_command_line
      attempt_command_action(ARGV[0], *ARGV[1..-1]) do
        print_help
        raise BadCommandError.new(
            %Q{! Unrecognized command. Command was "#{ARGV.first.inspect}" and options were #{ARGV[1..-1].inspect}.})
      end
    end



    def quit
      if interactive_mode
        exit(0)
      else
        puts "This command can only be run in shell mode."
      end
    end


    def cmd_h
      print_help
    end


    def cmd_j
      journal_names = book_set.journals.map(&:short_name)
      if interactive_mode
        journal_names
      else
        ap journal_names
      end
    end


    def cmd_r
      book_set.all_reports
    end


    def cmd_w
      book_set.all_reports_to_files(options.output_dir)
      nil
    end


    def cmd_x
      quit
    end


    def commands
      @commands_ ||= [
          Command.new('jo',  'journals',      -> (*_options) { cmd_j             }),
          Command.new('h',   'help',          -> (*_options) { cmd_h             }),
          Command.new('q',   'quit',          -> (*_options) { cmd_x             }),
          Command.new('r',   'report_hash',   -> (*_options) { cmd_r             }),
          Command.new('w',   'write_reports', -> (*_options) { cmd_w             }),
          Command.new('x',   'xit',           -> (*_options) { cmd_x             })
      ]
    end


    def find_command_action(command_string)
      # puts "command string: " + command_string
      result = commands.detect do |cmd|
        cmd.max_string.start_with?(command_string) \
      && \
      command_string.length >= cmd.min_string.length  # e.g. 'c' by itself should not work
      end
      result ? result.action : nil
    end


    # If a post-processor has been configured (e.g. YAML or JSON), use it.
    def post_process(object)
      post_processor ? post_processor.(object) : object
    end


    def post_processor
      options.post_processor
    end


    def call
      begin
        # By this time, the Main class has removed the command line options, and all that is left
        # in ARGV is the commands and their options.
        if @interactive_mode
          run_shell
        else
          process_command_line
        end

      rescue BadCommandError => error
        separator_line = "! #{'-' * 75} !\n"
        puts '' << separator_line << error.to_s << "\n" << separator_line
        exit(-1)
      end
    end
  end
end