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
    reconnect_timeout: 5000

  alias ElixirAmi.Action, as: Action
  alias ElixirAmi.Message, as: Message
  alias ElixirAmi.Response, as: Response
  use GenServer
  require Logger

  @type t :: ElixirAmi.Connection
  @type listener_id :: String.t
  @typep state :: Map.t

  defmacro schedule_reconnect() do
    quote [location: :keep] do
      state = var! state
      :erlang.send_after state.info.reconnect_timeout, self, :connect
    end
  end

  defmacro log(level, message) do
    quote do
      state = var! state
      Logger.unquote(level)("ElixirAmi: #{state.info.name} #{unquote(message)}")
    end
  end

  defmacro astsend(action) do
    quote do
      state = var! state
      action = unquote(action)
      data = [Action.serialize(action), "\r\n"]
      log :debug, "sending: #{inspect data}"
      :ok = :gen_tcp.send state.socket, data
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
  @spec add_listener(GenServer.server, function, function) :: listener_id
  def add_listener(server, filter, listener) do
    GenServer.call server, {:add_listener, filter, listener}
  end

  @doc """
  Removes an event listener.
  """
  @spec del_listener(GenServer.server, listener_id) :: :ok
  def del_listener(server, id) do
    GenServer.call server, {:del_listener, id}
  end

  @doc """
  GenServer callback
  """
  @spec init(t) :: {:ok, state}
  def init(info) do
    send self, :connect
    {:ok, %{
      info: info,
      socket: nil,
      ready: false,
      lines: [],
      actions: %{},
      listeners: %{}
    }}
  end

  @doc """
  GenServer callback
  """
  @spec handle_call(term, term, state) ::
    {:noreply, state} | {:reply, term, state}

  def handle_call({:add_listener, filter, listener}, _from, state) do
    id = ElixirAmi.Util.unique_id
    {:reply, id, %{state |
      listeners: Map.put(
        state.listeners, id, %{filter: filter, listener: listener}
      )
    }}
  end

  def handle_call({:del_listener, id}, _from, state) do
    {:reply, :ok, %{state | listeners: Map.delete(state.listeners, id)}}
  end

  def handle_call({:send, action}, from, state) do
    astsend action
    {:noreply, %{state |
      actions: Map.put(state.actions, action.id, %{
        caller: from,
        response: nil
      })
    }}
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
      :gen_tcp.close state.socket
    end
    {:stop, :normal, state}
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
        case :gen_tcp.connect(
          host, state.info.port,
          [{:mode, :binary}, {:packet, :line}, {:active, :once}],
          state.info.reconnect_timeout
        ) do
          {:ok, socket} ->
            log :info, "connected"
            {:noreply, %{state | ready: true, socket: socket}}
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
    {:tcp, socket, salutation = "Asterisk Call Manager" <> _rest},
    state = %{socket: socket}
  ) do
    log :debug, "got salutation: #{salutation}"
    :ok = :inet.setopts socket, [{:active, :once}]
    astsend Action.login(state.info.username, state.info.password)
    {:noreply, state}
  end

  def handle_info({:tcp, socket, "\r\n"}, state = %{socket: socket}) do
    message = Message.unserialize state.info.name, Enum.reverse(state.lines)
    log :debug, "Message: #{inspect message}"

    action_data = state.actions[message.action_id]
    state = case message do
      %ElixirAmi.Response{} -> if is_nil action_data do
        # Discard response without caller
        state
      else
        %{state | actions: Map.put(
          state.actions, message.action_id, %{action_data | response: message}
        )}
      end
      %ElixirAmi.Event{} -> if is_nil action_data do
        spawn fn ->
          for {id, l} <- state.listeners do
            spawn fn ->
              log :debug, "running listener #{id}"
              if l.filter.(state.info.name, message) do
                l.listener.(state.info.name, message)
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
    :ok = :inet.setopts socket, [{:active, :once}]
    {:noreply, %{state | lines: []}}
  end

  def handle_info({:tcp, socket, line}, state = %{socket: socket}) do
    {line, "\r\n"} = String.split_at line, -1
    log :debug, "got line: #{inspect line}"
    :ok = :inet.setopts socket, [{:active, :once}]
    {:noreply, %{state | lines: [line|state.lines]}}
  end

  def handle_info({:tcp_closed, socket}, state = %{socket: socket}) do
    log :debug, "asterisk closed connection"
    :gen_tcp.close state.socket
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
end