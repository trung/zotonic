%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2009 Marc Worrell
%% @date 2009-04-18
%% @doc Show the pager for the search result

%% Copyright 2009 Marc Worrell
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%% 
%%     http://www.apache.org/licenses/LICENSE-2.0
%% 
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(scomp_base_pager).
-behaviour(gen_scomp).

-export([init/1, varies/2, terminate/2, render/4]).
-export([test/0]).

-include("zotonic.hrl").

% Pages before/after the current page
-define(DELTA, 2).
-define(SLIDE, ?DELTA + ?DELTA + 1).


init(_Args) -> {ok, []}.
varies(_Params, _Context) -> undefined.
terminate(_State, _Context) -> ok.

render(Params, _Vars, Context, _State) ->
    Result       = proplists:get_value(result, Params),
    Dispatch     = proplists:get_value(dispatch, Params, search),
    HideSinglePage  = proplists:get_value(hide_single_page, Params),
    CleanedArgs  = proplists:delete(dispatch, proplists:delete(result, proplists:delete(hide_single_page, Params))),
    
    DispatchArgs = case proplists:is_defined(qargs, CleanedArgs) of
        true -> CleanedArgs;
        false -> [{qargs,true}|CleanedArgs]
    end,

    Result1 = case Result of
        #m{model=m_search, value=MResult} -> MResult;
        _ -> Result
    end,
    
    case Result1 of
        #m_search_result{result=[]} ->
            {ok, ""};
        #m_search_result{result=undefined} ->
            {ok, ""};
        #m_search_result{result=#search_result{pages=0}} ->
            {ok, ""};
        #m_search_result{result=#search_result{page=Page, pages=1}} ->
            case z_convert:to_bool(HideSinglePage) of
                true ->
                    {ok, "\n<ul class=\"pager block\"></ul>\n"};
                false ->
                    {ok, build_html(Page, 1, Dispatch, DispatchArgs, Context)}
            end;
        #m_search_result{result=#search_result{page=Page, pages=Pages}} ->
            Html = build_html(Page, Pages, Dispatch, DispatchArgs, Context),
            {ok, Html};
        #search_result{result=[]} ->
            {ok, ""};
        #search_result{pages=undefined} ->
            {ok, ""};
        #search_result{page=Page, pages=Pages} ->
            Html = build_html(Page, Pages, Dispatch, DispatchArgs, Context),
            {ok, Html};
        _ ->
            {error, "scomp_pager: search result is not a #search_result{}"}
    end.

build_html(Page, Pages, Dispatch, DispatchArgs, Context) ->
    {S,M,E} = pages(Page, Pages),
    Urls = urls(S, M, E, Dispatch, DispatchArgs, Context),
    [
        "\n<ul class=\"pager block\">",
            prev(Page, Pages, Dispatch, DispatchArgs, Context),
            [ url_to_li(Url, N, N == Page) || {N, Url} <- Urls ],
            next(Page, Pages, Dispatch, DispatchArgs, Context),
        "\n</ul>"
    ].

prev(Page, _Pages, _Dispatch, _DispatchArgs, _Context) when Page =< 1 ->
    ["\n<li class=\"disabled\">&laquo; prev</li>"];
prev(Page, _Pages, Dispatch, DispatchArgs, Context) ->
    Url = z_dispatcher:url_for(Dispatch, [{page,Page-1}|DispatchArgs], Context),
    ["\n<li><a href=\"",Url,"\">&laquo; prev</a></li>"].

next(Page, Pages, _Dispatch, _DispatchArgs, _Context) when Page >= Pages ->
    ["\n<li class=\"disabled\">next &raquo;</li>"];
next(Page, _Pages, Dispatch, DispatchArgs, Context) ->
    Url = z_dispatcher:url_for(Dispatch, [{page,Page+1}|DispatchArgs], Context),
    ["\n<li><a href=\"",Url,"\">next &raquo;</a></li>"].


url_to_li(sep, _, _) ->
    "\n<li class=\"pager-sep\">…</li>";
url_to_li(Url, N, false) ->
    ["\n<li><a href=\"",Url,"\">",integer_to_list(N),"</a></li>"];
url_to_li(Url, N, true) ->
    ["\n<li class=\"current\"><a href=\"",Url,"\">",integer_to_list(N),"</a></li>"].

pages(Page, Pages) ->
    Start = case Page - ?DELTA > 1 of
        true ->
            % Separate "1 ... 3"
            [1];
        false ->
            % Together "1 .. "
            seq(1, min(?SLIDE, Pages))
    end,
    Middle = case Page - ?DELTA > 1 of
        true ->
            seq(max(1,Page-?DELTA), min(Pages,Page+?DELTA));
        false ->
            []
    end,
    End = case Pages > Page + ?DELTA of
        true ->
            [Pages];
        false ->
            []
    end,
    {Start, Middle, End}.


urls(Start, Middle, End, Dispatch, DispatchArgs, Context) ->
    UrlStart  = [ {N, z_dispatcher:url_for(Dispatch, [{page,N}|DispatchArgs], Context)} || N <- Start ],
    UrlMiddle = [ {N, z_dispatcher:url_for(Dispatch, [{page,N}|DispatchArgs], Context)} || N <- Middle ],
    UrlEnd    = [ {N, z_dispatcher:url_for(Dispatch, [{page,N}|DispatchArgs], Context)} || N <- End ],
    {Part1,Next} = case Middle of
        [] ->
            {UrlStart, max(Start) + 1};
        [N|_] when N == 2 -> 
            % Now Start is always of the format [1]
            {UrlStart ++ UrlMiddle, lists:max(Middle) + 1};
        _ ->
            {UrlStart ++ [{none, sep}|UrlMiddle], lists:max(Middle) + 1}
    end,
    case End of
        [] ->
            Part1;
        [M|_] -> 
            if
                M == Next -> Part1 ++ UrlEnd;
                true -> Part1 ++ [{none, sep}|UrlEnd]
            end
    end.


max([]) -> 0;
max(L) -> lists:max(L).

seq(A,B) when B < A -> [];
seq(A,B) -> lists:seq(A,B).


min(A,B) when A < B -> A;
min(_,B) -> B.

max(A,B) when A > B -> A;
max(_,B) -> B.


test() ->
    C = z_context:new(default),
    R = #search_result{result=[a], pages=100, page=10},
    {ok, H} = render([{result,R}], [], C, []),
    list_to_binary(H).
    
