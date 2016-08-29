require 'mysql2'
require "mysql_getlock/version"

class MysqlGetlock
  attr_reader :mysql2, :key, :logger, :timeout

  TIMEOUT = -1 # inifinity
  PSEUDO_INFINITE_TIMEOUT = 4294967295 # for < 5.5.8

  class Error < ::StandardError; end
  class LockError < ::StandardError; end

  def initialize(mysql2:, key:, logger: nil, timeout: TIMEOUT)
    self.mysql2 = mysql2
    set_key(key)
    set_logger(logger)
    set_timeout(timeout)
  end

  # Use this setter if you reconnect mysql2 (which means renew Mysql2::Client instance),
  # but still want to use same MysqlGetlock instance
  def mysql2=(mysql2)
    @mysql2 = mysql2
    @mysql_version = nil
    @multiple_lockable = nil
    @infinite_timeoutable = nil
  end

  def lock
    if !multiple_lockable? and (current_session_key and current_session_key != key)
      raise Error, "get_lock() is already issued in the same connection for '#{current_session_key}'"
    end

    logger.info { "#{log_head}Wait #{timeout < -1 ? '' : "#{timeout} sec "}to acquire a mysql lock '#{key}'" } if logger
    results = mysql2.query(%Q[select get_lock('#{key}', #{timeout})], as: :array)
    case results.to_a.first.first
    when 1
      logger.info { "#{log_head}Acquired a mysql lock '#{key}'" } if logger
      set_current_session_key(key)
      true
    when 0
      logger.info { "#{log_head}Timeout to acquire a mysql lock '#{key}'" } if logger
      release_current_session_key
      false
    else # nil
      logger.info { "#{log_head}Unknown Error to acquire a mysql lock '#{key}'" } if logger
      release_current_session_key
      false
    end
  end

  def unlock
    if !multiple_lockable? and (current_session_key and current_session_key != key)
      raise Error, "get_lock() was issued for another key '#{current_session_key}', please unlock it beforehand"
    end

    results = mysql2.query(%Q[select release_lock('#{key}')], as: :array)
    release_current_session_key
    case results.to_a.first.first
    when 1
      logger.info { "#{log_head}Released a mysql lock '#{key}'" } if logger
      true
    when 0
      logger.info { "#{log_head}Failed to release a mysql lock since somebody else locked '#{key}'" } if logger
      false
    else # nil
      logger.info { "#{log_head}Mysql lock did not exist '#{key}'" } if logger
      true
    end
  end

  def locked?
    results = mysql2.query(%Q[select is_used_lock('#{key}')], as: :array)
    !!results.to_a.first.first
  end

  # return true if locked by myself
  def self_locked?
    results = mysql2.query(%Q[select is_used_lock('#{key}')], as: :array)
    lock_id = results.to_a.first.first
    return nil if lock_id.nil?
    results = mysql2.query(%Q[select connection_id()], as: :array)
    self_id = results.to_a.first.first
    self_id == lock_id
  end

  def synchronize(&block)
    raise LockError unless lock
    begin
      yield
    ensure
      unlock
    end
  end

  private

  def set_timeout(timeout)
    if infinite_timeoutable?
      @timeout = timeout
    else
      # To support MySQL < 5.5.8, put large number of seconds to express infinite timeout spuriously
      @timeout = (timeout < 0 ? PSEUDO_INFINITE_TIMEOUT : timeout)
    end
  end

  def set_key(key)
    @key = Mysql2::Client.escape(key)
  end

  def set_logger(logger)
    @logger = logger
  end

  def log_head
    "PID-#{::Process.pid} TID-#{::Thread.current.object_id.to_s(36)}: "
  end

  # From MySQL 5.7.5, multiple simultaneous locks can be acquired
  def multiple_lockable?
    return @multiple_lockable unless @multiple_lockable.nil?
    major, minor, patch = mysql_version
    @multiple_lockable = (major > 5) || (major == 5 && minor > 7) || (major == 5 && minor == 7 && patch >= 5)
  end

  # Before MySQL 5.5.8, a negative timeout value means infinite timeout on Windows. As of 5.5.8, this behavior applies on all platforms.
  def infinite_timeoutable?
    return @infinite_timeoutable unless @infinite_timeoutable.nil?
    major, minor, patch = mysql_version
    @infinite_timeoutable = (major > 5) || (major == 5 && minor > 5) || (major == 5 && minor == 5 && patch >= 8)
  end

  def mysql_version
    return @mysql_version if @mysql_version
    results = mysql2.query('select version()', as: :array)
    version = results.to_a.first.first
    major, minor, patch = version.split('.').map(&:to_i)
    @mysql_version = [major, minor, patch]
  end

  # Before MySQL 5.7.5, only a single simultaneous lock can be acquired
  @session_keys = {}

  def self.session_keys
    @session_keys
  end

  def current_session_key
    MysqlGetlock.session_keys[mysql2.object_id]
  end

  def set_current_session_key(key)
    MysqlGetlock.session_keys[mysql2.object_id] = key
  end

  def release_current_session_key
    MysqlGetlock.session_keys.delete(mysql2.object_id)
  end
end
