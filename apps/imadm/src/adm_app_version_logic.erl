-module(adm_app_version_logic).
%%%
% adm_app_version 业务逻辑模块
% adm_app_version business logic module
%%%

-export ([delete/1]).
-export ([save/1]).

-export([page/5]).

-ifdef(EUNIT).
-include_lib("eunit/include/eunit.hrl").
-endif.
-include_lib("imlib/include/log.hrl").
-include_lib("kernel/include/logger.hrl").
-include_lib("imlib/include/common.hrl").

%% ===================================================================
%% API
%% ===================================================================

-spec page(integer(), integer(), binary(), binary(), binary()) -> list().
page(Page, Size, Where, OrderBy, Column) when Page > 0 ->
    Offset = (Page - 1) * Size,
    Tb = app_version_repo:tablename(),
    Total = imboy_db:count_for_where(Tb, Where),
    Items = imboy_db:page_for_where(Tb,
        Size,
        Offset,
        Where,
        OrderBy,
        Column),
    imboy_response:page_payload(Total, Page, Size, Items).

save(Data) ->
    % Where = imboy_db:assemble_where([
    %     ["status", "=", maps:get(status, Data)]
    %     , ["type", "=", maps:get(type, Data)]
    %     , ["vsn", "=", maps:get(vsn, Data)]
    % ]),
    % Count = imboy_db:pluck(
    %     <<"app_ddl">>
    %     , Where
    %     , <<"count(*)">>
    %     , 0),

    % ?LOG([count, Count, " Where ", Where]),
    Id = ec_cnv:to_integer(maps:get(id, Data)),
    if Id > 0 ->
            imboy_db:update(
                app_version_repo:tablename()
                , <<"id = ", (ec_cnv:to_binary(Id))/binary>>
                , Data#{updated_at => imboy_dt:millisecond()}
            );
        true ->
            D2 = maps:remove(id, Data),
            app_version_repo:add(D2#{created_at => imboy_dt:millisecond()})
    end.

-spec delete(binary()) -> ok.
delete(Where) ->
    Tb = app_version_repo:tablename(),
    Sql = <<"DELETE FROM ", Tb/binary, " WHERE ", Where/binary>>,
    % ?LOG([Sql]),
    imboy_db:execute(Sql, []),
    ok.

%% ===================================================================
%% Internal Function Definitions
%% ===================================================================-

%

%% ===================================================================
%% EUnit tests.
%% ===================================================================

-ifdef(EUNIT).
%addr_test_() ->
%    [?_assert(is_public_addr(?PUBLIC_IPV4ADDR)),
%     ?_assert(is_public_addr(?PUBLIC_IPV6ADDR)),
%     ?_test(my_if_addr(inet)),
%     ?_test(my_if_addr(inet6))].
-endif.