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

## NOTICE

Note that

1. Before 5.7.5, only a single simultaneous lock can be acquired in a session, and `GET_LOCK()` releases any existing lock. This gem raises `MysqlGetlock::Error` on such situation.
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
  * Attempts to grab the lock and waits if it isn’t availabl. Returns true if successfully acquird a lock.
* locked?
  * Returns true if this lock is currently held by some.
* synchronize {}
  * Obtains a lock, runs the block, and releases the lock when the block completes.
* unlock
  * Releases the lock. Returns true if successfully released a lock.

Options of `MysqlGetlock.new` are:

* mysql2
  * Provide a mysql2 instance
* key
  * Key name for a distributed lock
* timeout
  * The timeout of trying to get the lock. A negative value means infinite timeout (default: -1)
* logger
  * Provide a logger for MysqlGetlock (for debug)

### Example

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

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sonots/mysql_getlock. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## ChangeLog

[CHANGELOG.md](./CHANGELOG.md)
