---
layout: post
title: Rate Limiter In Redis
---

# {{ page.title }}

<p class="meta">02 May, 2025</p>

Problem: External APIs limit the number of requests you can send during a time window. We should rate limit ourself instead of sending too many requests and running foul of their limits.

**Implementation using counter**

- Check if rate limited, if not, increment counter.
- `-1` result indicates there were already `rate_limit[:max]` number of requests processed in the `rate_limit[:time_window_in_secs]` window and can not proceed anymore.
- Time complexity: `O(1)`

```ruby
lua_script = <<-EOF
  local count = redis.call('GET', KEYS[1])
  if not count then
  -- EX: expire. This is the most important part of it.
    redis.call('SET', KEYS[1], 1, 'EX', tonumber(ARGV[1]))
    return
  end

-- rate limited
  if tonumber(count) >= tonumber(ARGV[2]) then
    return -1
  end

  redis.call('INCR', KEYS[1])
  return
EOF

conn.eval(
  lua_script,
  [rate_limit[:key]],
  [rate_limit[:time_window_in_secs], rate_limit[:max]]
)
```

**Implementation using counter, simpler than above**

- Instead of checking of key exists, set it with `NX`, which only sets if key does not exist.

```ruby
lua_script = <<-EOF
   -- set key to 0 if it doesn't exist with expiration
   local count = redis.call('SET', KEYS[1], 0, 'NX', 'GET', 'EX', tonumber(ARGV[1]))

   -- check if count is greater than max
   if count and tonumber(count) >= tonumber(ARGV[2]) then
     return -1
   end

   redis.call('INCR', KEYS[1])
   return
EOF

conn.eval(
  lua_script,
  ["KEY3"],
  [rate_limit[:time_window_in_secs], rate_limit[:max]]
)
```

- Only Redis 7+ supports using `GET` and `NX` options together in `SET` command. For <7, need to get the value using `GET` command.

```ruby
lua_script = <<-EOF
   redis.call('SET', KEYS[1], 0, 'NX', 'EX', tonumber(ARGV[1]))

   local count = redis.call('GET', KEYS[1])
   if count and tonumber(count) >= tonumber(ARGV[2]) then
     return -1
   end

   redis.call('INCR', KEYS[1])
   return
EOF

conn.eval(
  lua_script,
  ["KEY3"],
  [rate_limit[:time_window_in_secs], rate_limit[:max]]
)
```

**Implementation using Sorted Set and Hash**

```ruby
lua_script = <<-EOF
  local now = redis.call('TIME')[1]
  local buckets = redis.call('ZRANGEBYSCORE', KEYS[1], now-tonumber(ARGV[1]), now)

  if #buckets > 0 then
    local times = redis.call('HMGET', KEYS[2], unpack(buckets))
    local total = 1
    for i, count in ipairs(times) do
      total = total + count
    end
    if total > tonumber(ARGV[2]) then
      return -1
    end
  end

  redis.call('ZADD', KEYS[1], now, now)
  redis.call('HINCRBY', KEYS[2], now, 1)

  return now
EOF

lua_script = <<-EOF
  local current_time = redis.call('TIME')
  redis.call('ZADD', KEYS[1], current_time[1], current_time[1] .. current_time[2])
EOF

conn.eval(lua_script, ["KEY1"])
```

**Implementation with just Sorted Sets**

```python
def sliding_window_rate_limit(key, limit, window):
	r = redis.StrictRedis(host='localhost', port=6379, db=0)
	current_time = int(time.time())
	window_start = current_time - window
	requests_made = r.zcount(key, window_start, current_time)
	if requests_made < limit:
		r.zadd(key, {current_time: current_time})
		r.zremrangebyscore(key, '-inf', window_start)
		return True
	else:
		return False
```

Source: https://collabnix.com/rate-limiting-in-redis-explained/

Multiple things are wrong with the above implementation:

- Using wall clock `time.time()` in application code means requests from different computers that happen at the same time can have different time stored in the sorted set.
- It's not atomic; if another concurrent request happens between L5 and L6, it won't be visible and you'll go over the rate limit. Example of Read-Modify-Write.
- `time.time()` has granularity of 7 digits, ie `1708891610.2391622`. If two concurrent requests happen at the exact same time (as unlikely as it is), it'll be counted just as 1.
  - Using `TIME` command in Redis will solve this, since Redis is single threaded and no two requests can have the same time.
- `ZADD` has `O(log n)` time complexity which might be too much for a highly active system. And it's removing expired keys which has additional `O(log n + m)` time complexity.

**Implementation using MULTI**

```ruby
redis = Redis.new
count = redis.multi do |c|
  c.incr('key')
  c.expire('key', 60, nx: true)
  c.get('key')
end.last.to_i

raise RedisRateLimitError if count > max
```

LUA scripts have the following problems:

- Doesn't work with any of the layer 7 redis proxies (twemproxy, etc) used for HA.
- Can't test it with `MockRedis`.
- Blocks main Redis thread.

By using MULTI we can avoid that, while still ensuring you're not going over limit. The downside is the `key` value can get over max since we're incrementing regardless.
