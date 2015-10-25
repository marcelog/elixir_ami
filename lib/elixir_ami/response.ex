defmodule ElixirAmi.Response do
  @moduledoc """
  An AMI response is represented by this structure.

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
    action_id: nil,
    source: nil,
    success: nil,
    complete: true,
    keys: %{},
    variables: %{},
    events: []

  @type t :: ElixirAmi.Response

  @doc """
  Adds an event related to a response. Will also mark the response as completed
  if applies.
  """
  @spec add_event(t, ElixirAmi.Event.t) :: t
  def add_event(response, event) do
    response = %{response | events: [event|response.events]}
    if event.keys["eventlist"] === "Complete" do
      %{response | complete: true}
    else
      response
    end
  end

  @doc """
  This will return a Response given a list of received lines from Asterisk.
  """
  @spec unserialize(atom, iolist) :: t
  def unserialize(source, data) do
    Enum.reduce data, %ElixirAmi.Response{source: source}, fn(line, response) ->
      [k, v] = for s <- (String.split line, ":", parts: 2), do: String.strip s
      k = String.downcase k
      case k do
        "actionid" -> %{response | action_id: v}
        "response" -> %{response | success: (v === "Success")}
        "eventlist" -> %{response | complete: false}
        k -> %{response | keys: Map.put(response.keys, k, v)}
      end
    end
  end
end
