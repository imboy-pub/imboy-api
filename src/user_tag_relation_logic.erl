-module(user_tag_relation_logic).
%%%
% user_tag_relation 业务逻辑模块
% user_tag_relation business logic module
%%%

-export ([add/4]).
-export([merge_tag/4]).
-export([delete/3]).
-export([set/5]).
-export([tag_page/5]).

-ifdef(EUNIT).
-include_lib("eunit/include/eunit.hrl").
-endif.
-include_lib("imboy/include/log.hrl").
-include_lib("kernel/include/logger.hrl").
-include_lib("imboy/include/common.hrl").

%% ===================================================================
%% API
%% ===================================================================

-spec tag_page(binary(), integer(), integer(), binary(), binary()) -> list().
tag_page(Scene, Page, Size, Where, OrderBy) when Page > 0 ->
    Offset = (Page - 1) * Size,
    Total = user_tag_repo:count_for_where(Where),
    case user_tag_repo:page_for_where(Size, Offset, Where, OrderBy) of
        {ok, _, []} ->
            imboy_response:page_payload(Total, Page, Size, []);
        {ok, ColumnLi, Items0} ->
            Items1 = [tuple_to_list(Item) || Item <- Items0],
            % ColumnLi2 = ColumnLi ++ [<<"subtitle">>],
            Items2 = [lists:zipwith(
                fun(X, Y) -> {X, Y} end,
                ColumnLi, Row
                ) ||
                    Row <- Items1
            ],
            Items3 = [Item ++ [{<<"subtitle">>, user_tag_relation_repo:tag_subtitle(
                Scene
                , proplists:get_value(<<"id">>, Item, "")
                , proplists:get_value(<<"referer_time">>, Item, 0)
                )}] || Item <- Items2],

            % lager:info(io_lib:format("user_tag_relation_logic:tag_page/5 Items2:~p;~n", [Items2])),
            imboy_response:page_payload(Total, Page, Size, Items3);
        _ ->
            imboy_response:page_payload(Total, Page, Size, [])
    end.


%%% 删除标签，标签中的联系人不会被删除，使用此标签设置了分组的朋友圈，可见范围也将更新。
-spec delete(integer(), binary(), binary()) -> ok.
delete(Uid, Scene, Tag) ->
    Where = [
        imboy_func:implode("", ["creator_user_id = ", Uid]),
        imboy_func:implode("", ["scene = ", Scene]),
        imboy_func:implode("", ["name = '", Tag, "'"])
    ],
    TagWhere = imboy_func:implode(" AND ", Where),
    TagId = imboy_db:pluck(<<"user_tag">>, TagWhere, <<"id">>, 0),

    imboy_db:with_transaction(fun(Conn) ->
        % 删除 public.user_tag_relation
        UserTagTb = user_tag_relation_repo:tablename(),
        DelWhere = <<"scene = ", Scene/binary, " AND user_id = $1 AND tag_id = $2">>,
        DelSql = <<"DELETE FROM ", UserTagTb/binary," WHERE ", DelWhere/binary>>,
        % lager:info(io_lib:format("user_tag_relation_logic:delete/3 DelSql ~p, ~p; ~n", [DelSql, [Uid, TagId]])),
        epgsql:equery(Conn, DelSql, [Uid, TagId]),

        % 删除 public.tag
        TagTb = imboy_db:public_tablename(<<"user_tag">>),
        DelSql2 = <<"DELETE FROM ", TagTb/binary," WHERE id = $1">>,
        % lager:info(io_lib:format("user_tag_relation_logic:delete/3 DelSql2 ~p, p ~p; ~n", [DelSql2, TagId])),
        epgsql:equery(Conn, DelSql2, [TagId]),

        %
        UpTb = case Scene of
            <<"1">> ->
                imboy_db:public_tablename(<<"user_collect">>);
            <<"2">> ->
                imboy_db:public_tablename(<<"user_friend">>)
        end,
        UpSql = <<"UPDATE ", UpTb/binary, " SET tag = replace(tag, '", Tag/binary,",', '') WHERE tag like '%", Tag/binary, ",%';">>,
        lager:info(io_lib:format("user_tag_relation_logic:delete/3 UpSql  ~p; ~n", [UpSql])),

        _Res = epgsql:equery(Conn, UpSql),
        % 清理缓存
        user_tag_relation_repo:flush_subtitle(TagId),
        % lager:info(io_lib:format("user_tag_relation_logic:delete/3 UpSql  ~p, Res ~p; ~n", [UpSql, Res])),
        ok
    end),
    ok.


-spec set(integer(), binary(), list(), integer(), binary()) -> ok.
set(Uid, Scene, ObjectIds, TagId, TagName) when is_integer(TagId) ->
    set(Uid, Scene, ObjectIds, integer_to_binary(TagId), TagName);
set(Uid, Scene, ObjectIds, TagId, TagName) ->
    NowTs = imboy_dt:millisecond(),
    Uid2 = integer_to_binary(Uid),
    CreatedAt = integer_to_binary(NowTs),
    ObjectIds2 = [imboy_hashids:uid_decode(I) || I <- ObjectIds],

    RefCount = imboy_db:pluck(
        <<"user_tag_relation">>
        , <<"scene = ", Scene/binary," AND tag_id = ", TagId/binary, " AND user_id = ", Uid2/binary>>
        , <<"count(*)">>
        , 0
    ),
    imboy_db:with_transaction(fun(Conn) ->
        lager:info(io_lib:format("user_tag_relation_repo:set/5 ObjectIds2:~p, RefCount, ~p;~n", [ObjectIds2, [Conn , TagId,TagName, RefCount, Uid2, CreatedAt]])),
        % 保存 public.tag
        user_tag_relation_repo:update_tag(Conn, TagId,TagName, RefCount, Uid2, CreatedAt),

        % 插入 public.user_tag_relation
        [user_tag_relation_repo:save_user_tag_relation(Conn, Scene, Uid2, TagId, integer_to_binary(I), CreatedAt) || I <- ObjectIds2, I > 0],

        [change_scene_tag(Conn, Scene, Uid2, integer_to_binary(I), [TagName]) || I <- ObjectIds2, I > 0],
        ok
    end),
    % 清理缓存
    user_tag_relation_repo:flush_subtitle(TagId),
    ok.


%%% 添加标签
-spec add(integer(), binary(), binary(), list()) -> ok.
add(Uid, Scene, <<>>, [Tag]) ->
    lager:info(io_lib:format("user_tag_relation_logic:add/3 uid ~p scene ~p, tag: ~p; ~n", [Uid, Scene, Tag])),
    Count = imboy_db:pluck(
        <<"user_tag">>
        , <<"scene = ", Scene/binary, " AND name = ", Tag/binary>>
        , <<"id">>, 0
    ),
    case Count of
        0 ->
            Column = <<"(creator_user_id,scene,name,referer_time,created_at)">>,
            Value = [Uid, Scene, <<"'",Tag/binary, "'">>, 0, imboy_dt:millisecond()],
            imboy_db:insert_into(<<"user_tag">>, Column, Value),
            ok;
        _ ->
            <<"标签名已存在"/utf8>>
    end;

add(Uid, <<"1">>, ObjectId, Tag) ->
    do_add(<<"1">>, Uid, ObjectId, Tag),
    ok;
add(Uid, <<"2">>, ObjectId, Tag) ->
    do_add(<<"2">>, Uid, imboy_hashids:uid_decode(ObjectId), Tag),
    ok.
%% ===================================================================
%% Internal Function Definitions
%% ===================================================================-

change_scene_tag(Conn, Scene, Uid2, ObjectId, Tag) when is_list(Tag) ->
    {Table, Where} = case Scene of
        <<"1">> ->
            {
                imboy_db:public_tablename(<<"user_collect">>)
                , <<"user_id = ", Uid2/binary, " AND kind_id = '", ObjectId/binary, "'">>
            };
        <<"2">> ->

            {
                imboy_db:public_tablename(<<"user_friend">>)
                , <<"from_user_id = ", Uid2/binary, " AND to_user_id = ", ObjectId/binary>>
            }
    end,
    % 合并新旧tag，排重，不修改tag顺序
    TagBin = user_tag_relation_logic:merge_tag(Tag, Scene, Uid2, ObjectId),
    Sql = <<"UPDATE ", Table/binary," SET tag = '", TagBin/binary
        ,"' WHERE ", Where/binary>>,
    % lager:info(io_lib:format("user_tag_relation_repo:change_scene_tag/5  --------------------------------------------------------------------------------====================== sql:~p;~n", [Sql])),
    lager:info(io_lib:format("user_tag_relation_repo:change_scene_tag/5 sql:~s;~n", [Sql])),
    % epgsql:equery(Conn, Sql),
    {ok, Stmt} = epgsql:parse(Conn, Sql),
    epgsql:execute_batch(Conn, [{Stmt, []}]),
    % Res = epgsql:execute_batch(Conn, [{Stmt, []}]),
    % lager:info(io_lib:format("user_tag_relation_repo:change_scene_tag/5  ====================== Res:~p;~n", [Res])),
ok.

do_add(Scene, Uid, ObjectId, Tag) when is_integer(ObjectId) ->
    do_add(Scene, Uid, integer_to_binary(ObjectId), Tag);

% Tag = [] 移除特定对象的标签
do_add(Scene, Uid, ObjectId, []) ->
    Uid2 = integer_to_binary(Uid),
    imboy_db:with_transaction(fun(Conn) ->
        {Table, Where} = case Scene of
            <<"1">> ->
                {
                    imboy_db:public_tablename(<<"user_collect">>)
                    , <<"user_id = ", Uid2/binary, " AND kind_id = '", ObjectId/binary, "'">>
                };
            <<"2">> ->
                {
                    imboy_db:public_tablename(<<"user_friend">>)
                    , <<"from_user_id = ", Uid2/binary, " AND to_user_id = ", ObjectId/binary>>
                }
        end,
        Sql = <<"UPDATE ", Table/binary," SET tag = '' WHERE ", Where/binary>>,
        % lager:info(io_lib:format("user_tag_relation_logic:do_add/4 sql ~p; ~n", [Sql])),
        epgsql:equery(Conn, Sql),

        % 删除 public.user_tag_relation
        delete_object_tag(Conn, Scene, Uid2, ObjectId),
        ok
    end),
    ok;
%
do_add(Scene, Uid, ObjectId, Tag) ->
    % check public.tag
    % {ok,[<<"id">>,<<"name">>],[{1,<<"a">>},{4,<<"b">>}]}
    % {ok, _, Tag2} = user_tag_relation_repo:select_tag(
    %     <<"scene = ", Scene/binary, " AND name = any(string_to_array($1, ','))">>
    %     , [imboy_func:implode(",",Tag)]
    %     , <<"id, name">>
    % ),
    % TagIdNewLi = [Id || {Id, _} <- Tag2],
    % lager:info(io_lib:format("user_tag_relation_logic:add/4 TagIdNewLi:~p;~n", [TagIdNewLi])),

    NowTs = imboy_dt:millisecond(),
    Uid2 = integer_to_binary(Uid),
    CreatedAt = integer_to_binary(NowTs),
    imboy_db:with_transaction(fun(Conn) ->
        % 删除 public.user_tag_relation
        delete_object_tag(Conn, Scene, Uid2, ObjectId),

        % 插入 public.user_tag
        TagIdNewLi = [user_tag_relation_repo:save_tag(Conn, Uid2, Scene, CreatedAt, Name) || Name <- Tag],

        lager:info(io_lib:format("user_tag_relation_logic:add/4 TagIdNewLi:~p;~n", [TagIdNewLi])),

        % 插入 public.user_tag_relation
        [
            user_tag_relation_repo:save_user_tag_relation(Conn, Scene, Uid2, integer_to_binary(TagId), ObjectId, CreatedAt) || {TagId, _Name} <- TagIdNewLi, TagId > 0
        ],
        change_scene_tag(Conn, Scene, Uid2, ObjectId, Tag),
        % 清理缓存
        [user_tag_relation_repo:flush_subtitle(TagId) || {TagId, _} <- TagIdNewLi],

        ok
    end),
    ok.


% 删除 public.user_tag_relation
delete_object_tag(Conn, Scene, Uid, ObjectId) ->
    DelTb = user_tag_relation_repo:tablename(),
    DelWhere = <<"scene = ", Scene/binary, " AND user_id = ", Uid/binary," AND object_id = '", ObjectId/binary, "'">>,

    DelItems = imboy_db:list(Conn, <<"SELECT tag_id FROM ", DelTb/binary," WHERE ", DelWhere/binary>>),

    % lager:info(io_lib:format("user_tag_relation_logic:delete_object_tag/4 DelItems ~p; ~n", [DelItems])),

    DelSql = <<"DELETE FROM ", DelTb/binary," WHERE ", DelWhere/binary>>,
    % lager:info(io_lib:format("user_tag_relation_logic:delete_object_tag/4 DelSql ~p; ~n", [DelSql])),
    % Res = epgsql:equery(Conn, DelSql, []),

    {ok, Stmt} = epgsql:parse(Conn, DelSql),
    Res = epgsql:execute_batch(Conn, [{Stmt, []}]),
    % lager:error(io_lib:format("user_tag_relation_repo:delete_object_tag/4 Res:~p ~n", [Res])),

    % 清理缓存
    [user_tag_relation_repo:flush_subtitle(TagId) || {TagId} <- DelItems],
    ok.

% 合并新旧tag，排重，不修改tag顺序
merge_tag(Tag, Scene, Uid, ObjectId) ->
    Sql = <<"SELECT t.name FROM public.user_tag_relation ut LEFT JOIN public.tag t ON t.id = ut.tag_id WHERE ut.scene = ", Scene/binary, " AND ut.user_id = ", Uid/binary, " AND ut.object_id = '", ObjectId/binary,"'">>,
    % lager:error(io_lib:format("user_tag_relation_logic:merge_tag/4 Sql: ~p; ~n", [Sql])),
    TagOldLi = imboy_db:list(Sql),
    % lager:error(io_lib:format("user_tag_relation_logic:merge_tag/4 TagOldLi: ~p; ~n", [TagOldLi])),
    TagOld = imboy_func:implode(",", [I || {I} <- TagOldLi]),
    TagBin = imboy_func:implode(",", Tag),
    MergedTag = binary:split(<<TagBin/binary, ",", TagOld/binary>>, <<",">>, [global]),
    % lager:error(io_lib:format("user_tag_relation_logic:merge_tag/4 old ~p, new ~p, merged: ~p; ~n", [TagOld, TagBin, MergedTag])),
    imboy_func:implode(",", imboy_func:remove_dups(MergedTag)).

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