UNICORN_SETTINGS = {
  development: {
    socket:  '/tmp/unicorn.sock',
    pidfile: '/tmp/unicorn.pid',
    stderr:  '/tmp/unicorn.stderr.log',
    stdout:  '/tmp/unicorn.stdout.log',
    backlog: 1024,
    workers: 4
  },
  production: {
    socket:  '/var/run/unicorn.sock',
    pidfile: '/var/run/unicorn.pid',
    stderr:  '/var/log/unicorn.stderr.log',
    stdout:  '/var/log/unicorn.stdout.log',
    backlog: 2048,
    workers: 32
  },
  failover: {
    socket:  '/var/run/unicorn.sock',
    pidfile: '/var/run/unicorn.pid',
    stderr:  '/var/log/unicorn.stderr.log',
    stdout:  '/var/log/unicorn.stdout.log',
    backlog: 2048,
    workers: 16
  },
}
