# 0.2.3 (2016-08-31)

Enhancements:

* Add #try_lock

# 0.2.2 (2016-08-29)

Enhancements:

* Before MySQL 5.5.8, a negative timeout value did not mean infinite timeout on platforms except Windows. Apply large number of timeout (4294967295) if timeout < 0 is given to support infinite timeout spuriously for MySQL < 5.5.8.

# 0.2.1 (2016-08-28)

Enhancements:

* Raises `LockError` if #synchronize failed to acquore a lock

# 0.2.0 (2016-08-28)

Enhancements:

* Add #self_locked? to check lock is obtained by myself

# 0.1.2 (2016-08-28)

Enhancements:

* #lock returns true if it successfully acquired a lock

# 0.1.1 (2016-08-28)

Fixes:

* trivial but critical fix

# 0.1.0 (2016-08-28)

First version

