%% @author Justin Sheehy <justin@basho.com>
%% @author Andy Gross <andy@basho.com>
%% @copyright 2007-2009 Basho Technologies
%%
%%    Licensed under the Apache License, Version 2.0 (the "License");
%%    you may not use this file except in compliance with the License.
%%    You may obtain a copy of the License at
%%
%%        http://www.apache.org/licenses/LICENSE-2.0
%%
%%    Unless required by applicable law or agreed to in writing, software
%%    distributed under the License is distributed on an "AS IS" BASIS,
%%    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%    See the License for the specific language governing permissions and
%%    limitations under the License.

-module(webmachine).
-author('Justin Sheehy <justin@basho.com>').
-author('Andy Gross <andy@basho.com>').
-export([start/0, stop/0]).
-export([init_reqdata/2]).

-include("webmachine_logger.hrl").
-include_lib("include/wm_reqdata.hrl").

%% @spec start() -> ok
%% @doc Start the webmachine server.
start() ->
    webmachine_deps:ensure(),
    application:start(crypto),
    application:start(webmachine).

%% @spec stop() -> ok
%% @doc Stop the webmachine server.
stop() ->
    application:stop(webmachine).

init_reqdata(mochiweb, Request) ->
    Socket = Request:get(socket),
    Method = Request:get(method),
    RawPath = Request:get(raw_path), 
    Version = Request:get(version),
    Headers = Request:get(headers),
    InitState0 = wrq:create(Method,Version,RawPath,Headers),
    InitReq = InitState0#wm_reqdata{socket=Socket}, 
    {Peer, ReqData} = webmachine_request:get_peer(InitReq),
    PeerState = wrq:set_peer(Peer, ReqData),
    LogData = #wm_log_data{start_time=now(),
			   method=Method,
			   headers=Headers,
			   peer=PeerState#wm_reqdata.peer,
			   path=RawPath,
			   version=Version,
			   response_code=404,
			   response_length=0},
    PeerState#wm_reqdata{log_data=LogData}.




  
