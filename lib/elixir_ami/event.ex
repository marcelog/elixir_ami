defmodule ElixirAmi.Event do
  @moduledoc """
  An AMI event is represented by this structure.

  See: https://wiki.asterisk.org/wiki/display/AST/The+Asterisk+Manager+TCP+IP+API

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
    event: nil,
    source: nil,
    action_id: nil,
    keys: %{},
    variables: %{}

  @type t :: ElixirAmi.Event

  @doc """
  This will return an Event given a list of received lines from Asterisk.
  """
  @spec unserialize(atom, iolist) :: t
  def unserialize(source, data) do
    Enum.reduce data, %ElixirAmi.Event{source: source}, fn(line, event) ->
      [k, v] = for s <- (String.split line, ":", parts: 2), do: String.strip s
      k = String.downcase k
      case k do
        "actionid" -> %{event | action_id: v}
        "event" -> %{event | event: String.downcase(v)}
        k -> %{event | keys: Map.put(event.keys, k, v)}
      end
    end
  end
end
