Coolie
======

Coolie provides a really simple way of starting and stopping multiple parallel
worker processes that are meant to run repeatedly in an efficient way.

It requires no frameworks, databases or anything. It just does what you
want it to. And the best of it all: It will never ask for a raise!

How it works
------------

The Master takes a job as argument in the initializer, that responds to `setup` and `perform`.

When sending the `start_worker` message to the master, it forks a child process where it hands
the job to a new worker, which then sends the `setup` message to the job during initialization.
The purpose of the `setup` method is to load and initialize anything necessary to perform the job.

The master then starts the worker, which enters a run loop, that forks yet another child process where
the job receives the `perform` message.

Things missing
--------------

Coolie is still very much in its infancy, though the ambition isn't to build a [Resque] [resque] clone, but
instead build as small a tool with as few features as possible.

[resque]: https://github.com/resque/resque

There are, however, still features that are missing:

- Daemonization of the master
- Communication with the master through signals (something like [Unicorn] [unicorn])
- Basic logging
- Some sort of error handling
- Some sort of reaping of worker processes
- Documentation

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
