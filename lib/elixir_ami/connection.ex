defmodule ElixirAmi.Connection do
  @moduledoc """
  Main module. Connects to Asterisk and allows you to send actions, and receive
  events and responses.

  Copyright 2015 Marcelo Gornstein <marcelog@gmail.com>

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
  """
  require Record
  Record.defrecord :hostent, Record.extract(
    :hostent, from_lib: "kernel/include/inet.hrl"
  )

  defstruct \
    name: nil,
    host: nil,
    port: nil,
    username: nil,
    password: nil,
    connect_timeout: 5000,
    reconnect_timeout: 5000,
    ssl_options: nil,
    debug: false

  alias ElixirAmi.Action, as: Action
  alias ElixirAmi.Message, as: Message
  alias ElixirAmi.Response, as: Response
  use GenServer
  require Logger

  @type t :: ElixirAmi.Connection
  @type listener_id :: String.t
  @type listener_option :: :once
  @type listener_options :: [listener_option]
  @typep state :: Map.t

  defmacro schedule_reconnect() do
    quote [location: :keep] do
      state = var! state
      :erlang.send_after state.info.reconnect_timeout, self, :connect
    end
  end

  defmacro log(level, message) do
    quote bind_quoted: [
      level: level,
      message: message
    ] do
      state = var! state
      level_str = to_string level
      if((level_str !== "debug") or state.info.debug) do
        Logger.bare_log level, "ElixirAmi: #{state.info.name} #{message}"
      end
    end
  end

  defmacro astsend(action, is_login \\ false) do
    quote do
      state = var! state
      if state.ready or unquote(is_login) do
        action = unquote(action)
        data = [Action.serialize(action), "\r\n"]
        log :debug, "sending: #{inspect data}"
        :ok = :erlang.apply state.socket_module, :send, [state.socket, data]
      else
        :not_ready
      end
    end
  end

  @doc """
  Starts and link an AMI connection.
  """
  @spec start_link(t) :: GenServer.on_start
  def start_link(info) do
    GenServer.start_link __MODULE__, info, name: info.name
  end

  @doc """
  Starts an AMI connection.
  """
  @spec start(t) :: GenServer.on_start
  def start(info) do
    GenServer.start __MODULE__, info, name: info.name
  end

  @doc """
  Closes an AMI connection.
  """
  @spec close(GenServer.server) :: :ok
  def close(server) do
    GenServer.cast server, :close
  end

  @doc """
  Enables debug.
  """
  @spec debug(GenServer.server) :: :ok
  def debug(server) do
    GenServer.cast server, :debug
  end

  @doc """
  Disables debug.
  """
  @spec undebug(GenServer.server) :: :ok
  def undebug(server) do
    GenServer.cast server, :undebug
  end

  @doc """
  Tests if this connection is open and logged in.
  """
  @spec ready?(GenServer.server) :: boolean
  def ready?(server) do
    GenServer.call server, :ready?
  end

  @doc """
  Sends an action to asterisk.
  """
  @spec send_action(GenServer.server, Action.t) :: Response.t
  def send_action(server, action) do
    GenServer.call server, {:send, action}
  end

  @doc """
  Adds an event listener with the given filter.
  """
  @spec add_listener(
    GenServer.server, function, function, listener_options
  ) :: listener_id
  def add_listener(server, filter, listener, options \\ []) do
    GenServer.call server, {:add_listener, filter, listener, options}
  end

  @doc """
  Forward event.
  """
  @spec forward(
    GenServer.server, function, pid, listener_options
  ) :: listener_id
  def forward(server, filter, process, options \\ []) do
    add_listener server, filter, fn(node, _id, message) ->
      send process, {node, message}
    end, options
  end

  @doc """
  Removes an event listener.
  """
  @spec del_listener(GenServer.server, listener_id) :: :ok
  def del_listener(server, id) do
    GenServer.call server, {:del_listener, id}
  end

  @doc """
  Waits for an asyncagistart event on an optional channel and starts an
  agi application with elixir_agi.
  """
  @spec async_agi(GenServer.server, module, atom, boolean, String.t) :: :ok
  def async_agi(server, app_module, app_function, debug, channel \\ nil) do
    caller = self
    # Setup a listener for AsyncAGIStart so a new AGI App can be started
    add_listener(
      server,
      fn(_node, _listener_id, e) ->
        e.event === "asyncagistart" and (
          (is_nil channel) or (channel === e.keys["channel"])
        )
      end,
      fn(_node, listener_id, e) ->
        ets = :ets.new :agi, [
          {:read_concurrency, false},
          {:write_concurrency, false},
          :public
        ]
        :ets.give_away ets, caller, {:asyncagi_table}
        # Add a listener so AGI responses can be sent to caller.
        agi_command_listener = add_listener(
          server,
          fn(_node, _listener_id, agiexec_e) ->
            agiexec_e.event === "asyncagiexec" and
            agiexec_e.keys["channel"] === e.keys["channel"]
          end,
          fn(_node, _listener_id, agiexec_e) ->
            [{_, lines}] = :ets.lookup ets, :lines
            [{result, _}] = Map.to_list URI.decode_query(agiexec_e.keys["result"])
            true = :ets.insert ets, [{:lines, lines ++ [result]}]
          end
        )
        # Listen for a Hangup event for this channel so we can cleanup
        add_listener(
          server,
          fn(_node, _hangup_listener_id, hangup_e) ->
            hangup_e.event === "hangup" and
            hangup_e.keys["channel"] === e.keys["channel"]
          end,
          fn(_node, _listener_id, _hangup_e) ->
            del_listener server, agi_command_listener
          end,
          [:once]
        )
        # Read AGI variables
        env = URI.decode_query e.keys["env"]
        [{env, _}] = Map.to_list env
        lines = String.split(env, "\n") |>
          Enum.reverse |>
          tl |>
          Enum.reverse |>
          Enum.map(fn(x) -> "#{x}\n" end)
        true = :ets.insert_new ets, [{:lines, lines}]
        reader = fn() ->
          Enum.reduce_while((1..500000), nil, fn(_, acc) ->
            try do
              case :ets.lookup ets, :lines do
                [{:lines, []}] ->
                  :timer.sleep 100
                  {:cont, acc}
                [{:lines, [l|lines]}] ->
                  true = :ets.insert ets, [{:lines, lines}]
                  {:halt, l}
              end
            rescue
              _ -> {:halt, "HANGUP\n"}
            catch
              _,_ -> {:halt, "HANGUP\n"}
            end
          end)
        end
        writer = fn(data) ->
          [data, _] = data
          command_id = ElixirAmi.Util.unique_id
          action = Action.agi e.keys["channel"], data, command_id
          _response = send_action server, action
          :ok
        end
        init = fn() ->
          :ok
        end
        close = fn() ->
          :ok
        end
        agi = ElixirAgi.Agi.new init, close, reader, writer, debug
        spawn(fn() ->
          :erlang.apply app_module, app_function, [agi]
        end)
        # Don't start another AGI App if a channel was explicitely given
        if not is_nil channel do
          del_listener server, listener_id
        end
      end
    )
  end

  @doc """
  GenServer callback
  """
  @spec init(t) :: {:ok, state}
  def init(info) do
    send self, :connect
    socket_module = if(is_nil info.ssl_options) do
      :gen_tcp
    else
      :ssl
    end
    {:ok, %{
      info: info,
      socket: nil,
      ready: false,
      lines: [],
      login_action_id: nil,
      socket_module: socket_module,
      actions: %{},
      listeners: %{}
    }}
  end

  @doc """
  GenServer callback
  """
  @spec handle_call(term, term, state) ::
    {:noreply, state} | {:reply, term, state}

  def handle_call({:add_listener, filter, listener, options}, _from, state) do
    me = self
    id = ElixirAmi.Util.unique_id
    Logger.debug "adding listener: #{id}"
    listener = if :once in options do
      fn(name, id, message) ->
        listener.(name, id, message)
        del_listener me, id
      end
    else
      listener
    end
    {:reply, id, %{state |
      listeners: Map.put(
        state.listeners, id, %{filter: filter, listener: listener}
      )
    }}
  end

  def handle_call({:del_listener, id}, _from, state) do
    log :debug, "removing listener #{id}"
    {:reply, :ok, %{state | listeners: Map.delete(state.listeners, id)}}
  end

  def handle_call({:send, action}, from, state) do
    case astsend action do
      :not_ready -> {:reply, :not_ready, state}
      :ok -> {:noreply, %{state |
        actions: Map.put(state.actions, action.id, %{
          caller: from,
          response: nil
        })
      }}
    end
  end

  def handle_call(:ready?, _from, state) do
    {:reply, state.ready, state}
  end

  def handle_call(message, _from, state) do
    log :warn, "unknown call: #{inspect message}"
    {:reply, :not_implemented, state}
  end

  @doc """
  GenServer callback
  """
  @spec handle_cast(term, state) :: {:noreply, state} | {:stop, :normal, state}
  def handle_cast(:close, state) do
    log :debug, "shutting down"
    if not is_nil state.socket do
      :erlang.apply state.socket_module, :close, [state.socket]
    end
    {:stop, :normal, state}
  end

  def handle_cast(:debug, state) do
    {:noreply, %{state | info: %{state.info | debug: true}}}
  end

  def handle_cast(:undebug, state) do
    {:noreply, %{state | info: %{state.info | debug: false}}}
  end

  def handle_cast(message, state) do
    log :warn, "unknown cast: #{inspect message}"
    {:noreply, state}
  end

  @doc """
  GenServer callback
  """
  @spec handle_info(term, state) :: {:noreply, state}
  def handle_info(:connect, state) do
    log :info, "connecting"
    host = to_char_list state.info.host
    case :inet.gethostbyname host do
      {:ok, hostinfo} ->
        host = hd hostent(hostinfo, :h_addr_list)
        log :debug, "using address: #{inspect host}"
        ssl_options = if(is_nil state.info.ssl_options) do
          []
        else
          state.info.ssl_options
        end
        case :erlang.apply(state.socket_module, :connect, [
          host, state.info.port,
          [{:mode, :binary}, {:packet, :line}, {:active, :once}|ssl_options],
          state.info.reconnect_timeout
        ]) do
          {:ok, socket} ->
            log :info, "connected"
            {:noreply, %{state | socket: socket}}
          e ->
            log :error, "could not connect to #{state.info.host}: #{inspect e}"
            schedule_reconnect
            {:noreply, state}
        end
      e ->
        log :error, "could not resolve #{state.info.host}: #{inspect e}"
        schedule_reconnect
        {:noreply, state}
    end
  end

  def handle_info(
    {:ssl, socket, salutation = "Asterisk Call Manager" <> _rest},
    state = %{socket: socket}
  ) do
    handle_info {:tcp, socket, salutation}, state
  end

  def handle_info(
    {:tcp, socket, salutation = "Asterisk Call Manager" <> _rest},
    state = %{socket: socket}
  ) do
    log :debug, "got salutation: #{salutation}"
    :ok = setopts socket, [{:active, :once}], state
    login_action = Action.login(state.info.username, state.info.password)
    astsend login_action, true
    {:noreply, %{state | login_action_id: login_action.id}}
  end

  def handle_info({:ssl, socket, "\r\n"}, state = %{socket: socket}) do
    handle_info {:tcp, socket, "\r\n"}, state
  end

  def handle_info({:tcp, socket, "\r\n"}, state = %{socket: socket}) do
    message = Message.unserialize state.info.name, Enum.reverse(state.lines)
    log :debug, "Message: #{inspect message}"

    action_data = state.actions[message.action_id]
    state = case message do
      %ElixirAmi.Response{} -> cond do
        message.action_id === state.login_action_id ->
          %{state | ready: true}
        is_nil action_data ->
          # Discard response without caller
          state
        true ->
          %{state | actions: Map.put(
            state.actions, message.action_id, %{action_data | response: message}
          )}
      end
      %ElixirAmi.Event{} -> if is_nil action_data do
        spawn fn ->
          for {id, l} <- state.listeners do
            spawn fn ->
              log :debug, "checking listener #{id}"
              if l.filter.(state.info.name, id, message) do
                log :debug, "running listener #{id}"
                l.listener.(state.info.name, id, message)
              end
            end
          end
        end
        state
      else
        response = Response.add_event action_data.response, message
        %{state | actions: Map.put(
          state.actions, response.action_id, %{action_data | response: response}
        )}
      end
    end

    action_data = state.actions[message.action_id]
    response = if is_nil action_data do
      nil
    else
      action_data.response
    end

    state = if not is_nil response do
      if response.complete do
        GenServer.reply action_data.caller, response
        %{state | actions: Map.delete(state.actions, response.action_id)}
      else
        state
      end
    else
      state
    end
    :ok = setopts socket, [{:active, :once}], state
    {:noreply, %{state | lines: []}}
  end

  def handle_info({:ssl, socket, line}, state = %{socket: socket}) do
    handle_info {:tcp, socket, line}, state
  end

  def handle_info({:tcp, socket, line}, state = %{socket: socket}) do
    {line, "\r\n"} = String.split_at line, -1
    log :debug, "got line: #{inspect line}"
    :ok = setopts socket, [{:active, :once}], state
    {:noreply, %{state | lines: [line|state.lines]}}
  end

  def handle_info({:ssl_closed, socket}, state = %{socket: socket}) do
    handle_info {:tcp_closed, socket}, state
  end

  def handle_info({:tcp_closed, socket}, state = %{socket: socket}) do
    log :debug, "asterisk closed connection"
    :erlang.apply state.socket_module, :close, [state.socket]
    {:stop, :normal, state}
  end

  def handle_info(message, state) do
    log :warn, "unknown message: #{inspect message}"
    {:noreply, state}
  end

  @doc """
  GenServer callback
  """
  @spec code_change(term, state, term) :: {:ok, state}
  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  @doc """
  GenServer callback
  """
  @spec terminate(term, state) :: :ok
  def terminate(reason, state) do
    log :info, "terminating with: #{inspect reason}"
    :ok
  end

  defp setopts(socket, options, state) do
    opts_module = if(is_nil state.info.ssl_options) do
      :inet
    else
      :ssl
    end
    :ok = :erlang.apply opts_module, :setopts, [socket, options]
    :ok
  end
end