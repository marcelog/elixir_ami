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

  @spec logout() :: t
  def logout() do
    new "Logoff"
  end

  @spec ping() :: t
  def ping() do
    new "Ping"
  end

  @spec core_settings() :: t
  def core_settings() do
    new "CoreSettings"
  end

  @spec core_show_channels() :: t
  def core_show_channels() do
    new "CoreShowChannels"
  end

  @spec serialize(t) :: iolist
  def serialize(action) do
    [
      ["actionid", ": ", action.id, "\r\n"],
      ["action", ": ", action.name, "\r\n"],
      (for {k, v} <- action.keys, do: "#{k}: #{v}\r\n"),
      (for {k, v} <- action.variables, do: "Variable: #{k}=#{v}\r\n")
    ]
  end

  @spec new(String.t, Map.t, Map.t) :: t
  def new(name, keys \\ %{}, variables \\ %{}) do
    %ElixirAmi.Action{
      id: to_string(:erlang.unique_integer),
      name: name,
      keys: keys,
      variables: variables
    }
  end
end