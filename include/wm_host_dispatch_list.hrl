%% @doc Dispatch list on a per-host basis.
%% host      = atom specificying the symbolic hostname, also set in the wm_reqdata.  Use 'default' for the catch-all host
%% hostname  = the primary hostname, lowercase (eg. "www.example.com")
%% hostalias = list of accepted aliases, lowercase (eg. [ "example.com", "example.net" ])
%% redirect  = boolean, set to true to redirect GET requests to the main host
%% dispatch_list = list of {pathspec, resource, args}

-record(wm_host_dispatch_list, {host, hostname, hostalias, redirect, dispatch_list}).