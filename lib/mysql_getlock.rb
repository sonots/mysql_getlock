require 'mysql2'
require "mysql_getlock/version"

class MysqlGetlock
  attr_reader :mysql2, :key, :logger, :timeout

  TIMEOUT = -1 # inifinity
  class Error < ::StandardError; end

  def initialize(mysql2:, key:, logger: nil, timeout: TIMEOUT)
    @mysql2 = mysql2
    @key = Mysql2::Client.escape(key)
    @logger = logger
    @timeout = Integer(timeout)
  end

  def lock
    if !multiple_lockable? and (current_session_key and current_session_key != key)
      raise Error, "get_lock() is already issued in the same connection for '#{current_session_key}'"
    end

    logger.info { "MysqlGetlock: Wait acquiring a lock: #{key}" } if logger
    results = mysql2.query(%Q[select get_lock('#{key}', #{timeout})], as: :array)
    case results.to_a.first.first
    when 1
      logger.info { "MysqlGetlock: Acquired a lock: #{key}" } if logger
      set_current_session_key(key)
    when 0
      logger.info { "MysqlGetlock: Timeout to acquire a lock: #{key}" } if logger
      release_current_session_key
    else # nil
      logger.info { "MysqlGetlock: Unknown Error to acquire a lock: #{key}" } if logger
      release_current_session_key
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
      logger.info { "MysqlGetlock: Released a lock: #{key}" } if logger
      true
    when 0
      logger.info { "MysqlGetlock: Failed to release since somebody else locked: #{key}" } if logger
      false
    else # nil
      logger.info { "MysqlGetlock: Lock did not exist: #{key}" } if logger
      true
    end
  end

  def locked?
    results = mysql2.query(%Q[select is_free_lock('#{key}')], as: :array)
    results.to_a.first.first == 0
  end

  def synchronize(&block)
    lock
    begin
      yield
    ensure
      unlock
    end
  end

  private

  # From MySQL 5.7.5, multiple simultaneous locks can be acquired
  def multiple_lockable?
    return @multiple_lockable unless @multiple_lockable.nil?
    results = mysql2.query('select version()', as: :array)
    version = results.to_a.first.first
    major, minor, patch = version.split('.').map(&:to_i)
    @multiple_lockable = (major > 5) || (major == 5 && minor > 7) || (major == 5 && minor == 7 && patch >= 5)
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
