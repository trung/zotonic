%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2009 Marc Worrell
%% @date 2009-04-15
%% @doc Search the database, interfaces to specific search routines.

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

-module(z_search).
-author("Marc Worrell <marc@worrell.nl").

%% interface functions
-export([
    search/2,
    search/3,
    search_pager/3,
    search_pager/4,
    search_result/3,
    pager/3,
    pager/4
]).

-include_lib("zotonic.hrl").

-define(OFFSET_LIMIT, {1,?SEARCH_PAGELEN}).
-define(OFFSET_PAGING, {1,20000}).

%% @doc Search items and handle the paging.  Uses the default page length.
%% @spec search({Name, SearchPropList}, Page, #context) -> #search_result
search_pager(Search, Page, Context) ->
    search_pager(Search, Page, ?SEARCH_PAGELEN, Context).

%% @doc Search items and handle the paging
%% @spec search_pager({Name, SearchPropList}, Page, PageLen, #context) -> #search_result
search_pager(Search, Page, PageLen, Context) ->
    SearchResult = search(Search, ?OFFSET_PAGING, Context),
    pager(SearchResult, Page, PageLen, Context).


pager(#search_result{pagelen=undefined} = SearchResult, Page, Context) ->
    pager(SearchResult, Page, ?SEARCH_PAGELEN, Context);
pager(SearchResult, Page, Context) ->
    pager(SearchResult, Page, SearchResult#search_result.pagelen, Context).

pager(#search_result{result=Result} = SearchResult, Page, PageLen, _Context) ->
    Total = length(Result),
    Pages = mochinum:int_ceil(Total / PageLen), 
    Offset = (Page-1) * PageLen + 1,
    OnPage = case Offset =< Total of
        true ->
            {P,_} = z_utils:split(PageLen, lists:nthtail(Offset-1, Result)),
            P;
        false ->
            []
    end,
    Next = if Offset + PageLen < Total -> false; true -> Page+1 end,
    Prev = if Page > 1 -> Page-1; true -> 1 end,
    SearchResult#search_result{
        result=OnPage,
        all=Result,
        total=Total,
        page=Page,
        pagelen=PageLen,
        pages=Pages,
        next=Next,
        prev=Prev
    }.

%% @doc Search with the question and return the results
%% @spec search({Name, SearchPropList}, #context) -> #search_result
search(Search, Context) ->
    search(Search, ?OFFSET_LIMIT, Context).

%% @doc Perform the named search and its arguments
%% @spec search({Name, SearchPropList}, {Offset, Limit}, Context) -> #search_result
search({SearchName, Props} = Search, Limit, Context) ->
    Props1 = case proplists:get_all_values(cat, Props) of
        [] -> Props;
        Cats -> [{cat, Cats} | proplists:delete(cat, Props)]
    end,
    Props2 = case proplists:get_all_values(cat_exclude, Props1) of
        [] -> Props1;
        CatsX -> [{cat_exclude, CatsX} | proplists:delete(cat_exclude, Props1)]
    end,
    PropsSorted = lists:keysort(1, Props2),
    case z_notifier:first({search_query, {SearchName, PropsSorted}, Limit}, Context) of
        undefined -> 
            ?LOG("Unknown search query ~p", [Search]),
            #search_result{};
        Result -> 
            search_result(Result, Limit, Context)
    end;
search(Name, Limit, Context) ->
    search({z_convert:to_atom(Name), []}, Limit, Context).


%% @doc Handle a return value from a search function.  This can be an intermediate SQL statement that still needs to be
%% augmented with extra ACL checks.
%% @spec search_result(Result, Limit, Context) -> #search_result
search_result(#search_result{} = S, _Limit, _Context) ->
    S;
search_result(#search_sql{} = Q, Limit, Context) ->
    Q1 = reformat_sql_query(Q, Context),
    {Sql, Args} = concat_sql_query(Q1, Limit),
    case Q#search_sql.run_func of
        F when is_function(F) ->
            F(Q, Sql, Args, Context);
        _ -> 
            Rows = case Q#search_sql.assoc of
                false ->
                    Rs = z_db:q(Sql, Args, Context),
                    case Rs of
                        [{_}|_] -> [ R || {R} <- Rs ];
                        _ -> Rs
                    end;
                true ->
                    z_db:assoc_props(Sql, Args, Context)
            end,
            #search_result{result=Rows}
    end.


concat_sql_query(#search_sql{select=Select, from=From, where=Where, group_by=GroupBy, order=Order, limit=Limit, args=Args}, {OffsetN, LimitN}) ->
    Where1 = case Where of
        [] -> [];
        _ -> "where " ++ Where
    end,
    Order1 = case Order of
        [] -> [];
        _ -> "order by "++Order
    end,
    GroupBy1 = case GroupBy of
        [] -> [];
        _ -> "group by "++GroupBy
    end,
    {Parts, FinalArgs} = case Limit of
        undefined ->
            N = length(Args),
            Args1 = Args ++ [OffsetN-1, LimitN],
            {["select", Select, "from", From, Where1, GroupBy1, Order1, "offset", [$$|integer_to_list(N+1)], "limit", [$$|integer_to_list(N+2)]], Args1};
        _ ->
            {["select", Select, "from", From, Where1, GroupBy1, Order1, Limit], Args}
    end,
    {string:join(Parts, " "), FinalArgs}.
    

%% @doc Inject the ACL checks in the SQL query.
%% @spec reformat_sql_query(#search_sql, Context) -> #search_sql
reformat_sql_query(#search_sql{where=Where, tables=Tables, args=Args, cats=TabCats, cats_exclude=TabCatsExclude} = Q, Context) ->
    {ExtraWhere, Args1} = lists:foldl(
                                fun(Table, {Acc,As}) ->
                                    {W,As1} = add_acl_check(Table, As, Context),
                                    {[W|Acc], As1}
                                end, {[], Args}, Tables),
    ExtraWhere1 = lists:foldl(
                                fun({Alias, Cats}, Acc) ->
                                    case add_cat_check(Alias, false, Cats, Context) of
                                        [] -> Acc;
                                        CatCheck -> [CatCheck | Acc]
                                    end
                                end, ExtraWhere, TabCats),
    ExtraWhere2 = lists:foldl(
                                fun({Alias, Cats}, Acc) ->
                                    case add_cat_check(Alias, true, Cats, Context) of
                                        [] -> Acc;
                                        CatCheck -> [CatCheck | Acc]
                                    end
                                end, ExtraWhere1, TabCatsExclude),

    Where1 = lists:flatten(concat_where(ExtraWhere2, Where)),
    Q#search_sql{where=Where1, args=Args1}.


%% @doc Concatenate the where clause with the extra ACL checks using "and".  Skip empty clauses.
%% @spec concat_where(ClauseList, CurrentWhere) -> NewClauseList
concat_where([], Acc) -> 
    Acc;
concat_where([[]|Rest], Acc) -> 
    concat_where(Rest, Acc);
concat_where([W|Rest], []) -> 
    concat_where(Rest, [W]);
concat_where([W|Rest], Acc) ->
    concat_where(Rest, [W, " and "|Acc]).
    

%% @doc Create extra 'where' conditions for checking the access control
%% @spec add_acl_check({Table, Alias}, Args, Context) -> {Where, NewArgs}
add_acl_check({rsc, Alias}, Args, Context) ->
    add_acl_check1(rsc, Alias, Args, Context);
add_acl_check(_, Args, _Context) ->
    {[], Args}.


%% @doc Create extra 'where' conditions for checking the access control
%% @spec add_acl_check1(Table, Alias, Args, Context) -> {Where, NewArgs}
add_acl_check1(Table, Alias, Args, Context) ->
    % N = length(Args),
    case z_acl:can_see(Context) of
        ?ACL_VIS_GROUP ->
            % Admin or supervisor, can see everything
            {[], Args};
        ?ACL_VIS_PUBLIC -> 
            % Anonymous users can only see public published content
            Sql = Alias ++ ".visible_for = 0",
            Sql1 = case Table of
                rsc ->
                    Sql++" and "
                    ++Alias++".is_published and "
                    ++Alias++".publication_start <= now() and "
                    ++Alias++".publication_end >= now()";
                _ ->
                    Sql
            end,
            {Sql1, Args};
        ?ACL_VIS_COMMUNITY ->
            % Can see published community and public content or any content from one of the user's groups
            Sql = Alias ++ ".visible_for in (0,1) ",
            Sql1 = case Table of
                rsc ->
                    Sql++" and "
                    ++Alias++".is_published and "
                    ++Alias++".publication_start <= now() and "
                    ++Alias++".publication_end >= now()";
                _ ->
                    Sql
            end,
            N = length(Args),
            Sql2 = "((" ++ Sql1 ++ ") or "++Alias++".id = $"++integer_to_list(N+1)
                    ++" or group_id in (select rg.group_id from rsc_group rg where rg.rsc_id = $"++integer_to_list(N+1)++"))",
            {Sql2, Args ++ [Context#context.user_id]}
    end.


%% @doc Create the 'where' conditions for the category check
%% @spec add_cat_check(Alias, Cats, Context) -> Where
add_cat_check(_Alias, _Exclude, [], _Context) ->
    [];
add_cat_check(Alias, Exclude, Cats, Context) ->
    Ranges = m_category:ranges(Cats, Context),
    CatChecks = [ cat_check1(Alias, Exclude, Range) || Range <- Ranges ],
    case CatChecks of
        [] -> [];
        [_CatCheck] -> CatChecks;
        _ -> "(" ++ string:join(CatChecks, case Exclude of false -> " or "; true -> " and " end) ++ ")"
    end.

    cat_check1(Alias, false, {From,From}) ->
        Alias ++ ".pivot_category_nr = "++integer_to_list(From);
    cat_check1(Alias, false, {From,To}) ->
        Alias ++ ".pivot_category_nr >= " ++ integer_to_list(From)
        ++ " and "++ Alias ++ ".pivot_category_nr <= " ++ integer_to_list(To);

    cat_check1(Alias, true, {From,From}) ->
        Alias ++ ".pivot_category_nr <> "++integer_to_list(From);
    cat_check1(Alias, true, {From,To}) ->
        [$(|Alias] ++ ".pivot_category_nr < " ++ integer_to_list(From)
        ++ " or "++ Alias ++ ".pivot_category_nr > " ++ integer_to_list(To) ++ ")".
