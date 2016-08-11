# ElixirAmi

An [Asterisk](http://www.asterisk.org/) client for the [AMI](https://wiki.asterisk.org/wiki/display/AST/AMI+v2+Specification)
protocol written in [Elixir](http://elixir-lang.org/). For a quick introduction to AMI you can read [this](http://marcelog.github.io/articles/php_asterisk_manager_interface_protocol_tutorial_introduction.html).

This is similar to [PAMI](https://github.com/marcelog/PAMI) for PHP, [NAMI](https://github.com/marcelog/Nami) for NodeJS, and
[erlami](https://github.com/marcelog/erlami) for Erlang.

----

# Using it with Mix

To use it in your Mix projects, first add it as a dependency:

```elixir
def deps do
  [{:elixir_ami, "~> 0.0.3"}]
end
```
Then run mix deps.get to install it.

Also add the app in your mix.exs file:
```elixir
  [
    applications: [:logger, :elixir_ami],
    ...
  ]
```
----

# Connecting to Asterisk

To create a connection, you need to specify the connection information like this:

```elixir
alias ElixirAmi.Connection, as: Conn

connection_data = %Conn{
  name: :my_connection,       # The gen_server connection will be registered with this name
  host: "192.168.0.123",
  port: 5038,
  username: "frank",
  password: "lean",
  connection_timeout: 5000,   # How many millseconds to wait when connecting
  reconnect_timeout: 5000,    # Wait this many milliseconds before attempting reconnection,
  ssl_options: nil            # Or [ssl:ssl_option()]. Will try a regular TCP connection if this value is nil
}
```
## Using the built in supervisor

The recommended way to create a connection is to take advantage of the built in supervisor,
using `ElixirAmi.Supervisor.Ami` (this connection will be automatically supervised and restarted
in case of a crash):

```elixir
alias ElixirAmi.Supervisor.Ami, as AmiSup

{:ok, pid} = AmiSup.new connection_data
```

## Creating a connection without the supervisor

To start a connection under your own supervision tree or OTP application structure,
use `ElixirAmi.Connection.start_link` or `ElixirAmi.Connection.start` as follows:

```elixir

{:ok, pid} = Conn.start_link connection_data
```

# Sending an action

You can find actions inside the [Action](https://github.com/marcelog/elixir_ami/blob/master/lib/elixir_ami/action.ex)
module (feel free to open pull requests to add more!).

```elixir
alias ElixirAmi.Action, as: Action

Conn.send_action :my_connection, Action.ping

%ElixirAmi.Response{
  source: :my_connection,
  action_id: "-576460752303423460",
  complete: true,
  events: [],
  keys: %{
    "ping" => "Pong",
    "timestamp" => "1445770404.871145"
  },
  success: true,
  variables: %{}
}
```
The response will *make its best* to return all related events for the response (there might be
cases where the Asterisk will violate the AMI protocol and this will **not** be possible). Sometimes
the implementation of the events is not consistent, or it's just broken. Please report any issues you
may have and I'll try to fix them.

All related events will be returned in the `events` key of the response.

## Sending custom actions

If you want to send an action that is not already supported in the `Action` module, you have two choices:

 * Open a pull request (recommended :))
 * Use the function `Action.new/3` to create your custom action and send it. This is actually
 the function used behind the scenes to send the supported actions.

### Using Action.new

```elixir
Conn.send_action :my_connection, Action.new(
  "my_cool_action",
  %{mykey: "myvalue"},
  %{myvar: "myvarvalue"}
)
```

Where the arguments are:

  1. The action name
  2. The key values for the action (optional)
  3. Additional variables (optional)

----

# Receiving events

To receive asynchronous events (i.e: not related to a response) you can register listeners
with their filters, both are of type function and will receive 3 arguments:

 * source: The connection name.
 * listener_id: The current listener id.
 * event: The event received from asterisk.

## Registering event listeners

```elixir
listener_id = Conn.add_listener(
  :my_connection,
  fn(source, listener_id, event) -> event.event === "varset" end,
  &MyModule.my_function/3
)
```

The filter must return `true` or `false`. If it returns `true`, the second function
(in this case `MyModule.my_function/2` will be called with the same arguments) to
process the event, the result is discarded.

## Removing event listeners

```elixir
Conn.del_listener :my_connection, listener_id
```

----
# Documentation

Feel free to take a look at the [documentation](http://hexdocs.pm/elixir_ami/)
served by hex.pm or the source itself to find more.

----

# License
The source code is released under Apache 2 License.

Check [LICENSE](https://github.com/marcelog/elixir_ami/blob/master/LICENSE) file for more information.

----
