# ElixirAmi

An [Asterisk](http://www.asterisk.org/) client for the [AMI](https://wiki.asterisk.org/wiki/display/AST/AMI+v2+Specification)
protocol written in [Elixir](http://elixir-lang.org/).

This is similar to [PAMI](https://github.com/marcelog/PAMI) for PHP, [NAMI](https://github.com/marcelog/Nami) for NodeJS, and
[erlami](https://github.com/marcelog/erlami) for Erlang.

----

# Using it with Mix

To use it in your Mix projects, first add it as a dependency:

```elixir
def deps do
  [{:elixir_ami, "~> 0.0.1"}]
end
```
Then run mix deps.get to install it.

----

# Connecting to Asterisk

Use `ElixirAmi.Connection.start_link` or `ElixirAmi.Connection.start` as follows:

```elixir
alias ElixirAmi.Connection, as: Conn

{:ok, pid} = Conn.start_link %{
  name: "my_connection",
  host: "192.168.0.123",
  port: 5038,
  username: "frank",
  password: "lean",
  connection_timeout: 5000,   # How many millseconds to wait when connecting
  reconnect_timeout: 5000     # Wait this many milliseconds before attempting reconnection
}
```

# Sending an action

You can find actions inside the [Action](https://github.com/marcelog/elixir_ami/blob/master/lib/elixir_ami/action.ex)
module.

```elixir
alias ElixirAmi.Action, as: Action

Conn.send_action pid, Action.ping

%ElixirAmi.Response{
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

----

# Documentation

Feel free to take a look at the [documentation](http://hexdocs.pm/elixir_ami/)
served by hex.pm or the source itself to find more.

----

# License
The source code is released under Apache 2 License.

Check [LICENSE](https://github.com/marcelog/elixir_ami/blob/master/LICENSE) file for more information.

----
