-module(feedback_ds).
%%%
% feedback 业务逻辑模块
% feedback business logic module
%%%

-export([page/4, page/5]).
-export ([add/10]).
-export ([remove/2]).

-export([add_reply/1, page_reply/4]).

-ifdef(EUNIT).
-include_lib("eunit/include/eunit.hrl").
-endif.
-include_lib("imlib/include/log.hrl").
-include_lib("kernel/include/logger.hrl").
-include_lib("imlib/include/common.hrl").

%% ===================================================================
%% API
%% ===================================================================

%%% 用户反馈分页列表
-spec page(integer(), integer(), binary(), binary()) -> list().
page(Page, Size, Where, OrderBy) when Page > 0 ->
    Column = <<"id as feedback_id, device_id, type, rating, contact_detail, body, attach, reply_count, status, updated_at, created_at, app_vsn">>,
    page(Page, Size, Where, OrderBy, Column).
-spec page(integer(), integer(), binary(), binary(), binary()) -> list().
page(Page, Size, Where, OrderBy, Column) when Page > 0 ->
    Offset = (Page - 1) * Size,
    Tb = feedback_repo:tablename(),
    Total = imboy_db:count_for_where(Tb, Where),
    Items = imboy_db:page_for_where(Tb,
        Size,
        Offset,
        Where,
        OrderBy,
        Column),
    imboy_response:page_payload(Total, Page, Size, Items).


%%% add方法
%%% 新增用户反馈
-spec add(integer(), binary(), binary(), binary(), binary(), binary(), binary(), binary(), binary(), binary()) ->
    {ok, list(), list()} | {error, any()}.
% feedback_ds:add(Uid, Did, COS, COSV, AppVsn, ContactDetail, Body, Attach)
add(Uid, Did, COS, COSV, AppVsn, Type, Rating, ContactDetail, Body, Attach) ->
    FeedbackMd5 = imboy_hasher:md5(imboy_cnv:implode("", [
        Uid, Did, AppVsn, Type, Body
        ])),

    Count = imboy_db:pluck(<<"feedback">>,
       <<"feedback_md5 = '", FeedbackMd5/binary, "'">>,
       <<"count(*)">>,
       0),
    if Count > 0 ->
            ok;
        true ->
            feedback_repo:add(Uid, Did, COS, COSV, AppVsn, Type, Rating, ContactDetail, Body, Attach, FeedbackMd5)
    end.

-spec remove(integer(), binary()) -> ok.
remove(Uid, FeedbackId) ->
    % 状态: -1 删除  0 禁用  1 启用 (待回复）  2 已回复  3 已完结（不允许回复了）
    Where = imboy_cnv:implode("", ["user_id = ", Uid," AND id = ", FeedbackId]),
    imboy_db:update(feedback_repo:tablename(), Where, [
        {<<"status">>, <<"-1">>}
        , {<<"updated_at">>, integer_to_binary(imboy_dt:millisecond())}
    ]),
    % feedback_repo:delete(Uid, FeedbackId),
    % Key = {user_device_name, Uid, FeedbackId},
    % imboy_cache:flush(Key),
    ok.


%%% 用户反馈分页列表
-spec page_reply(integer(), integer(), binary(), binary()) -> list().
page_reply(Page, Size, Where, OrderBy) when Page > 0 ->
    Offset = (Page - 1) * Size,
    Column = <<"id as feedback_reply_id, feedback_id, feedback_reply_pid, replier_user_id, replier_name, body, status, updated_at, created_at">>,
    Tb = feedback_reply_repo:tablename(),
    Total = imboy_db:count_for_where(Tb, Where),
    Items = imboy_db:page_for_where(Tb,
        Size,
        Offset,
        Where,
        OrderBy,
        Column),
    imboy_response:page_payload(Total, Page, Size, Items).

% feedback_ds:add_reply(#{feedback_id => 1, feedback_reply_pid => 0, replier_user_id => 1, replier_name => <<"sss">>, body => "", created_at => imboy_dt:millisecond()})
add_reply(Data) ->
    FeedbackId = maps:get(<<"feedback_id">>, Data),
    Tb = feedback_reply_repo:tablename(),
    imboy_db:insert_into(Tb, Data),
    Where = <<"id = ", (ec_cnv:to_binary(FeedbackId))/binary>>,
    KV = [
        % 状态: -1 删除  0 禁用  1 启用 (待回复）  2 已回复  3 已完结（不允许回复了）'
        {<<"status">>, <<"2">>}
        , {<<"reply_count">>, {raw, <<"reply_count + 1">>}}
        , {<<"updated_at">>, imboy_dt:millisecond()}
    ],
    imboy_db:update(feedback_repo:tablename(), Where, KV),
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
