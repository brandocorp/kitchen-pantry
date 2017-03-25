# Credit to http://codeincomplete.com/posts/ruby-daemons/
require 'kitchen'
require 'kitchen/pantry/version'
require 'kitchen/pantry/log'
require 'chef_zero/server'
require 'chef_zero/data_store/raw_file_store'
require 'mixlib/cli'

module Kitchen
  class Pantry
    EXIT_CODES = {
      1 => "A generic error was encountered",
      2 => "Server already running",
      3 => "Server not running",
      4 => "Unsupported action",
    }.freeze

    InvalidAction = Class.new(StandardError)

    def self.local_ipaddress
      local = Socket.ip_address_list.find {|intf| intf.ipv4_private? }
      local.ip_address
    end

    include Mixlib::CLI

    option :host,
           :short => '-H host',
           :long => '--host HOST',
           :description => "The hostname or IP address to bind to",
           :default => local_ipaddress

    option :port,
           :short => '-P port',
           :long => '--port PORT',
           :description => "The port to listen on",
           :default => '12358'

    option :daemon,
           :short => '-d',
           :long => '--daemon',
           :description => 'Run as a daemon process',
           :default => false,
           :proc => Proc.new {|val| val.to_s.downcase.to_sym == :true }

    option :ssl,
           :long => "--ssl",
           :description => 'Use SSL with self-signed certificate',
           :default => false,
           :proc => Proc.new {|val| val.to_s.downcase.to_sym == :true }

    option :log_level,
           :short => "-l LEVEL",
           :long  => "--log-level LEVEL",
           :description => "Sets the log level",
           :default => :info,
           :in => [:debug, :info, :warn, :error, :fatal],
           :proc => Proc.new { |l| l.to_sym }

    option :log_file,
           :long => "--log-file FILE",
           :description => "The log file",
           :required => false


    def self.run
      new.run
    end

    def run(argv=ARGV)
      action = parse_options(argv).first
      exit_code(4) unless %w(start stop).include?(action)
      send(action)
    ensure
      cleanup
    end

    def start
      setup_logging
      if existing_pid?
        exit_code(2)
        Pantry::Log.error "Another server is already running. Check #{pidfile}"
        exit(1)
      end
      daemonize if daemonize?
      write_pid
      start_server
    end

    def stop
      exit_code(3) unless existing_pid?
      setup_logging
      check_pid
      stop_server
    end

    def setup_logging
      setup_console_logging
      setup_file_logging if logfile?
    end

    def setup_console_logging
      if logfile?
        # if we have a log file, send stdout/stderr to the log file
        $stderr.reopen(logfile, 'a')
        $stdout.reopen($stderr)
      elsif daemonize?
        # if we're a daemon, send everything to /dev/null
        $stderr.reopen('/dev/null', 'a')
        $stdout.reopen($stderr)
      end
    end

    def setup_file_logging
      [ChefZero::Log, Log].each do |logger|
        logger.level(config[:log_level])
        if logfile? && daemonize?
          logger.init(logfile)
        elsif logfile?
          logger.use_log_devices(Logger.new(STDOUT), Logger.new(logfile))
        else
          logger.init(STDOUT)
        end
      end
    end

    def existing_pid?
      pidfile? && pid_status(pidfile) == :running
    end

    def check_pid
      if pidfile?
        case pid_status(pidfile)
        when :running, :not_owned
          Pantry::Log.error "Another server is already running. Check #{pidfile}"
          exit(1)
        when :dead
          Pantry::Log.warn "Stale pid detected. Removing pidfile."
          File.delete(pidfile)
        end
      end
    end

    def pid_status(pidfile)
      return :exited unless File.exists?(pidfile)
      pid = read_pid
      return :dead if pid == 0
      Process.kill(0, pid)      # check process status
      :running
    rescue Errno::ESRCH
      :dead
    rescue Errno::EPERM
      :not_owned
    end

    def read_pid
      Log.debug "Reading pid from #{pidfile}"
      ::File.read(pidfile).to_i
    end

    def write_pid
      if pidfile?
        begin
          Log.debug "Writing pid to #{pidfile}"
          File.open(pidfile, ::File::CREAT | ::File::EXCL | ::File::WRONLY){|f| f.write("#{Process.pid}") }
          at_exit { File.delete(pidfile) if File.exists?(pidfile) }
        rescue Errno::EEXIST
          check_pid
          retry
        end
      end
    end

    def start_server
      Log.debug "Starting server"
      # prepare_file_store
      server = ChefZero::Server.new(server_options)
      server.start(true)
    end

    def server_options
      # config.merge(
      #   data_store: ChefZero::DataStore::RawFileStore.new(chef_repo_path, true)
      # )
      config
    end

    # def prepare_file_store
    #   data_path = File.join(chef_repo_path, 'organizations', 'chef')
    #   FileUtils.mkdir_p(data_path)
    #   %w(cookbooks clients data data_bags environments nodes roles).each do |dir|
    #     FileUtils.mkdir_p(File.join(data_path, dir))
    #   end
    # end

    def chef_repo_path
      File.join(ENV['HOME'], '.kitchen', "pantry_#{config[:port]}")
    end

    def logfile?
      logfile && File.exist?(logfile)
    end

    def logfile
      config[:log_file]
    end

    def pidfile?
      File.exist?(pidfile)
    end

    def pidfile
      File.join(ENV['HOME'], '.kitchen', "pantry-#{config[:port]}.pid")
    end

    def daemonize?
      config[:daemon]
    end

    def daemonize
      Log.debug "Daemonizing the current process: #{Process.pid}"
      exit if fork
      Process.setsid
      exit if fork
      Dir.chdir "/"
    end

    def exit_code(id)
      Pantry::Log.error EXIT_CODES[id]
      exit(id)
    end

    def cleanup
      File.delete(pidfile) if File.exist?(pidfile)
      FileUtils.rm_rf(chef_repo_path)
    end
  end
end
