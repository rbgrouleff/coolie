Sisyphus
======

Sisyphus provides a really simple way of starting and stopping multiple parallel
worker processes that are meant to run repeatedly in an efficient way.

It requires no frameworks, databases or anything. It just does what you
want it to - until you tell it to stop doing it.

How it works
------------

The Master takes a job as argument in the initializer, that responds to `setup` and `perform`.

When sending the `start_worker` message to the master, it forks a child process where it hands
the job to a new worker, which then sends the `setup` message to the job during initialization.
The purpose of the `setup` method is to load and initialize anything necessary to perform the job.

The master then starts the worker, which enters a run loop, that forks yet another child process where
the job receives the `perform` message.

Getting started
---------------

1. Add `gem 'sisyphus'` to your Gemfile and run `bundle`
2. Subclass `Sisyphus::Job` and implement the `perform` method
3. Instantiate the `Sisyphus::Master`, giving it an instance of your job
   and optionally an `options` hash. The `options` hash supports the
   following keys:
   * `:workers` which specifies the number (`FixNum`) of workers you need.
   * `:logger` which is used to log any exceptions the
     master or workers encounter. The logger should quack like a
     `Logger` instance from the Ruby stdlib. Exceptions are logged with the
     `Logger::WARN` level.
   * `:execution_strategy` which can either be `Sisyphus::SimpleExecutionStrategy` or
     `Sisyphus::ForkingExecutionStrategy`. This is the strategy used by
     workers when performing the job. The default is
     `Sisyphus::ForkingExecutionStrategy`.
4. You can start workers by doing one of the following things:
   * Send the `start` message to the master, if the `options` hash was
     provided. This starts a run loop which monitors workers and
     restarts them if they encounters uncaught exceptions
   * Otherwise send the `start_worker` message to the master as many
     times as the number of workers needed. This doesn't start any run
     loop, and there is no monitoring of workers.

If you need to stop workers, you can do it one at the time by sending
the `stop_worker` message to the master or stop them all by sending the
`stop_all` message.

When stopping workers, they are allowed to finish what they are doing,
before they stop. Which means you're screwed right now, if the `perform`
method in your job never returns.

The master registers signal handlers when you send it the `start`
message and enters a run loop.

The signals the master responds to are:

- `SIGINT` tells the master to gracefully stop all workers and shut down
- `SIGTTIN` tells the master to spawn a new worker
- `SIGTTOU` tells the master to stop a worker

Things missing
--------------

Sisyphus is still very much in its infancy, though the ambition isn't to build a [Resque] [resque] clone, but
instead build as small a tool with as few features as possible.

There are, however, still features that are missing:

- Force killing workers
- Daemonization of the master
- The master should have a shutdown immediately signal
- Communication with the master through signals (something like [Unicorn] [unicorn])
- Basic logging
- Some sort of error handling
- Some sort of reaping of worker processes
- Documentation

[resque]: https://github.com/resque/resque
[unicorn]: http://unicorn.bogomips.org/

Contributing
------------

Feel free to report issues or fork, fix and submit pull requests.

License
-------

Copyright 2013 Rasmus Bang Grouleff

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
