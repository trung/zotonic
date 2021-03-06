%% @author Arjan Scherpenisse <arjan@scherpenisse.net>
%% @copyright 2009 Arjan Scherpenisse
%% @date 2009-10-03
%%
%% @doc Set a value in the zotonic visitor record.

-module(service_base_visitor_get).
-author("Arjan Scherpenisse <arjan@scherpenisse.net>").

-svc_title("Retrieve a value from the Zotonic visitor record.").
-svc_needauth(false).

-export([process_get/2]).

-include_lib("zotonic.hrl").


process_get(_ReqData, Context) ->
    case z_context:get_q("key", Context) of
        X when X =:= undefined orelse X =:= [] ->
            {error, missing_arg, "key"};
        Key ->
            R = [{key, Key}, {value, z_context:get_visitor(list_to_atom(Key), Context)}],
            z_convert:to_json(R)
    end.


