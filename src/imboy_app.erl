-module(imboy_app).
-behaviour(application).

-export([start/2]).
-export([stop/1]).

-include("common.hrl").


start(_Type, _Args) ->
    %%启动存储pid的树据 可以采用 ets 表格处理 但是为了方便集群处理 我采用的mnesia
    chat_online:init(),
    % begin handler
    Routes = imboy_router:get_routes(),
    ?LOG(Routes),
    Dispatch = cowboy_router:compile(Routes),
    {ok, Port} = application:get_env(imboy, http_port),
    {ok, _} = cowboy:start_clear(imboy_http_listener,
        [{port, Port}],
        #{
            middlewares => [
                cowboy_router,
                % verify_middleware,
                auth_middleware,
                cowboy_handler
            ],
            metrics_callback => do_metrics_callback(),
            stream_handlers => [cowboy_metrics_h, cowboy_stream_h],
            env => #{dispatch => Dispatch}
        }
    ),
    % end handler
    imboy_sup:start_link().

do_metrics_callback() ->
   fun(Metrics) ->
      error_logger:error_msg("@@ metrics~n~p~n", [Metrics]),
      ok
   end.

stop(_State) ->
    ok = cowboy:stop_listener(imboy_http_listener).
