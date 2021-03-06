# MysqlGetlock

Distributed locking using mysql `get_lock()`. Unlike distributed locking using redis, this ensures releasing orphaned lock.

## How It Works

This gem uses MySQL [get_lock()](http://dev.mysql.com/doc/refman/5.7/en/miscellaneous-functions.html#function_get-lock).

Simple ruby codes which describes how it works are as follows:

```ruby
mysql.query(%Q[select get_lock('db_name.key', -1)])
puts 'get lock'
begin
  # do a job
ensure
  mysql.query(%Q[select release_lock('db_name.key')])
end
```

MySQL `get_lock()` has a characteristic that the lock is implicitly released when your session terminates (either normally or abnormally). Safe!

## NOTE

Note that

1. Before 5.7.5, only a single simultaneous lock can be acquired in a session, and `get_lock()` releases any existing lock.
 * This gem raises `MysqlGetlock::Error` at `#lock` if another `get_lock()` for another key is issued in a session to prevent accidental releases of existing lock.
 * MEMO: lock twice for the same key in a session does not block, only one lock is held for both mysql < 5.7.5 and >= 5.7.5.
2. The key name is global in a mysql instance. It is advised to use database-specific or application-specific lock names such as `db_name.str` or `app_name.environment.str`

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mysql_getlock'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install mysql_getlock

## Usage

Similarly with ruby standard library [mutex](https://ruby-doc.org/core-2.2.0/Mutex.html), following methods are available:

* lock
  * Attempts to grab the lock and waits if it isn’t available. Returns true if successfully acquired a lock
* locked?
  * Returns true if this lock is currently held by some (including myself)
* synchronize {}
  * Obtains a lock, runs the block, and releases the lock when the block completes. Raises `MysqlGetlock::LockError` if failed to acquire a lock
* unlock
  * Releases the lock. Returns true if successfully released a lock.
* self_locked?
  * Returns true if this lock is currently held by myself.
* try_lock
  * Attempts to grab the lock and returns immediately without waits. Returns true if successfully acquired a lock

Options of `MysqlGetlock.new` are:

* mysql2
  * Provide a mysql2 instance
* key
  * Key name for a distributed lock
* timeout
  * The timeout of trying to get the lock. A negative value means infinite timeout (default: -1)
* logger
  * Provide a logger for MysqlGetlock (for debug)

## Example

```ruby
require 'mysql2'
require 'mysql_getlock'

mysql2 = Mysql2::Client.new # Mysql2::Client.new(options)
mutex = MysqlGetlock.new(mysql2: mysql2, key: 'db_name.lock_key')

mutex.lock
begin
  puts 'get lock'
ensure
  mutex.unlock
end

mutex.synchronize do
  puts 'get lock'
end
```

## USE CASE 1: Elimiate SPOF of cron job

To eliminate SPOF of cron jobs, add following codes to your ruby scripts to be ran:

```ruby
mutex = MysqlGetlock.new(mysql2: mysql2, key: 'db_name.lock_key')

# Exit immediately if a process at another host holds a lock already
exit(0) unless mutex.try_lock

# Hold an acquired lock 10 seconds at least because it is not assured
# that cron jobs at multiple hosts start at exactly same time.
started = Time.now
begin
  # do your main work
ensure
  sleep((duration = 10 - (Time.now - started).to_f) > 0 ? duration : 0)
  mutex.unlock rescue nil
end
```

Run this script in cron on multiple hosts.

## NOTICE

We've encountered a situation that the mysql connection is disconnected from mysql server shortly, and the GET_LOCK is unlocked unexpectedly without waiting to finish a job. We need another trick to resolve this situation, and [redis_getlock](https://github.com/sonots/redis_getlock) would be a way to choose.

## ToDo

* Prepare a command line tool like [daemontools' setlock](https://cr.yp.to/daemontools/setlock.html)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sonots/mysql_getlock. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## ChangeLog

[CHANGELOG.md](./CHANGELOG.md)
