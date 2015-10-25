defmodule ElixirAmi.Action do
  @moduledoc """
  An AMI action is represented by this structure.

  See: https://wiki.asterisk.org/wiki/display/AST/AMI+Actions

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
  defstruct \
    id: nil,
    name: nil,
    keys: %{},
    variables: %{}

  @type t :: ElixirAmi.Action

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_Login
  """
  @spec login(String.t, String.t) :: t
  def login(username, password) do
    new "Login", %{
      username: username,
      secret: password
    }
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_AbsoluteTimeout
  """
  @spec absolute_timeout(String.t, Integer.t) :: t
  def absolute_timeout(channel, timeout) do
    new "AbsoluteTimeout", %{
      channel: channel,
      timeout: timeout
    }
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_AgentLogoff
  """
  @spec agent_logoff(String.t, boolean) :: t
  def agent_logoff(agent, soft) do
    new "AgentLogoff", %{
      agent: agent,
      soft: to_string(soft)
    }
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_Agents
  """
  @spec agents() :: t
  def agents() do
    new "Agents"
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_AGI
  """
  @spec agi(String.t, String.t, String.t) :: t
  def agi(channel, command, command_id) do
    new "AGI", %{
      channel: channel,
      command: command,
      commandid: command_id
    }
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_Bridge
  """
  @spec bridge(String.t, String.t, boolean) :: t
  def bridge(channel1, channel2, tone) do
    new "Bridge", %{
      channel1: channel1,
      channel2: channel2,
      tone: (if tone do
        "yes"
      else
        "no"
      end)
    }
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_Logoff
  """
  @spec logoff() :: t
  def logoff() do
    new "Logoff"
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_Ping
  """
  @spec ping() :: t
  def ping() do
    new "Ping"
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_CoreSettings
  """
  @spec core_settings() :: t
  def core_settings() do
    new "CoreSettings"
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_CoreShowChannels
  """
  @spec core_show_channels() :: t
  def core_show_channels() do
    new "CoreShowChannels"
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_Getvar
  """
  @spec get_var(String.t, String.t) :: t
  def get_var(channel, name) do
    new "Getvar", %{
      channel: channel,
      variable: name
    }
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_Hangup
  """
  @spec hangup(String.t, Integer.t) :: t
  def hangup(channel, cause) do
    new "Hangup", %{
      channel: channel,
      cause: to_string(cause)
    }
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_ListCommands
  """
  def list_commands() do
    new "ListCommands"
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_ListCategories
  """
  def list_categories(filename) do
    new "ListCategories", %{
      filename: filename
    }
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_Monitor
  """
  @spec monitor(String.t, String.t, String.t, String.t) :: t
  def monitor(channel, file, format, mix) do
    new "Monitor", %{
      channel: channel,
      file: file,
      format: format,
      mix: mix
    }
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_Originate
  """
  @spec originate(
    String.t, String.t, String.t, String.t,
    Integer.t, String.t, String.t, boolean, String.t, Map.t
  ) :: t
  def originate(
    channel, exten, context, priority,
    timeout, caller_id, account, async, codecs, variables
  ) do
    new "Originate", %{
      channel: channel,
      exten: exten,
      context: context,
      priority: priority,
      timeout: to_string(timeout),
      caller_id: caller_id,
      account: account,
      async: to_string(async),
      codecs: codecs
    }, variables
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_Originate
  """
  @spec originate(
    String.t, String.t, String.t,
    Integer.t, String.t, String.t, boolean, String.t, Map.t
  ) :: t
  def originate(
    channel, application, data,
    timeout, caller_id, account, async, codecs, variables
  ) do
    new "Originate", %{
      channel: channel,
      application: application,
      data: data,
      timeout: to_string(timeout),
      caller_id: caller_id,
      account: account,
      async: to_string(async),
      codecs: codecs
    }, variables
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_Park
  """
  @spec park(String.t, String.t, Integer.t, String.t) :: t
  def park(channel, channel2, timeout, parking_lot) do
    new "Park", %{
      channel: channel,
      channel2: channel2,
      timeout: timeout,
      parkinglot: parking_lot
    }
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_ParkedCalls
  """
  @spec parked_calls() :: t
  def parked_calls() do
    new "ParkedCalls"
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_PauseMonitor
  """
  @spec pause_monitor(String.t) :: t
  def pause_monitor(channel) do
    new "PauseMonitor", %{
      channel: channel
    }
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_Reload
  """
  @spec reload(String.t) :: t
  def reload(module) do
    new "Reload", %{
      module: module
    }
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_SendText
  """
  @spec send_text(String.t, String.t) :: t
  def send_text(channel, message) do
    new "Setvar", %{
      channel: channel,
      message: message
    }
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_Setvar
  """
  @spec set_var(String.t, String.t, String.t) :: t
  def set_var(channel, name, value) do
    new "Setvar", %{
      channel: channel,
      variable: name,
      value: to_string(value)
    }
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_SIPpeers
  """
  @spec sip_peers() :: t
  def sip_peers() do
    new "SIPpeers"
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_SIPqualifypeer
  """
  @spec sip_qualify_peer(String.t) :: t
  def sip_qualify_peer(peer) do
    new "SIPqualifypeer", %{
      peer: peer
    }
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_Status
  """
  @spec status([String.t]) :: t
  def status(variables, channel \\ nil) do
    new "Status", %{
      variables: Enum.join(variables, ","),
      channel: channel
    }
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_StopMonitor
  """
  @spec stop_monitor(String.t) :: t
  def stop_monitor(channel) do
    new "StopMonitor", %{
      channel: channel
    }
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_UnpauseMonitor
  """
  @spec unpause_monitor(String.t) :: t
  def unpause_monitor(channel) do
    new "UnpauseMonitor", %{
      channel: channel
    }
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_UserEvent
  """
  @spec user_event(String.t, Map.t) :: t
  def user_event(event, headers \\ %{}) do
    keys = Map.put headers, :userevent, event
    new "UserEvent", keys
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_VoicemailUsersList
  """
  @spec voicemail_users_list() :: t
  def voicemail_users_list() do
    new "VoicemailUsersList"
  end

  @doc """
  See: https://wiki.asterisk.org/wiki/display/AST/ManagerAction_WaitEvent
  """
  @spec wait_event(Integer.t) :: t
  def wait_event(timeout) do
    new "WaitEvent", %{
      timeout: timeout
    }
  end

  @doc """
  Transforms an action structure into an iolist suitable to be sent through
  a socket.
  """
  @spec serialize(t) :: iolist
  def serialize(action) do
    [
      ["actionid", ": ", action.id, "\r\n"],
      ["action", ": ", action.name, "\r\n"],
      (Enum.reduce action.keys, [], fn({k, v}, acc) ->
        if is_nil v do
          acc
        else
          ["#{k}: #{v}\r\n"|acc]
        end
      end),
      (for {k, v} <- action.variables, do: "Variable: #{k}=#{v}\r\n")
    ]
  end

  @doc """
  Creates a new action structure from the given name, keys, and variables.
  """
  @spec new(String.t, Map.t, Map.t) :: t
  def new(name, keys \\ %{}, variables \\ %{}) do
    %ElixirAmi.Action{
      id: ElixirAmi.Util.unique_id,
      name: name,
      keys: keys,
      variables: variables
    }
  end
end