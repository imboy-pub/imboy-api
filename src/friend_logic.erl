-module(friend_logic).
%%%
%  friend 业务逻辑模块
%%%
-export([search/1]).
-export([add_friend/4]).
-export([confirm_friend/4]).
-export([confirm_friend_resp/2]).
-export([delete_friend/2]).
-export([move_to_category/3]).
-export([information/2]).
-export([category_friend/1]).
-export([friend_list/1]).

-include_lib("imboy/include/log.hrl").


-spec add_friend(CurrentUid::integer(),
    To::binary(),
    Payload::list(),
    CreatedAt::integer() | CreatedAt::binary()
) -> ok | {error, Msg::binary(), Param::binary()}.
add_friend(_, undefined, _, _) ->
    {error, <<"Parameter error">>, <<"to">>};
add_friend(_, _, undefined, _) ->
    {error, <<"Parameter error">>, <<"payload">>};
add_friend(_, _, _, undefined) ->
    {error, <<"Parameter error">>, <<"created_at">>};
add_friend(CurrentUid, To, Payload, CreatedAt) when is_binary(CreatedAt) ->
    add_friend(CurrentUid, To, Payload, binary_to_integer(CreatedAt));
add_friend(CurrentUid, To, Payload, CreatedAt) ->
    ToId = imboy_hashids:uid_decode(To),
    NowTs = imboy_dt:millisecond(),
    From = imboy_hashids:uid_encode(CurrentUid),
    Id = <<"af_", From/binary, "_", To/binary>>,
    % ?LOG([is_binary(Payload), Payload]),
    % 存储消息
    msg_s2c_ds:write_msg(CreatedAt, Id, Payload,
        CurrentUid, ToId, NowTs),
    Msg = [{<<"id">>, Id},
        {<<"type">>, <<"S2C">>},
        {<<"from">>, From},
        {<<"to">>, To},
        {<<"payload">>, Payload},
        {<<"created_at">>, CreatedAt},
        {<<"server_ts">>, NowTs}
    ],
    % ?LOG(Msg),
    MsLi = [0, 1500, 1500, 3000, 5000, 7000],
    message_ds:send_next(ToId, Id, jsone:encode(Msg, [native_utf8]), MsLi),
    ok.

-spec confirm_friend(CurrentUid::integer(),
    From::binary(),
    To::binary(),
    Payload::list()
) -> {ok, list()} | {error, Msg::binary(), Param::binary()}.
confirm_friend(_, undefined, _, _) ->
    {error, <<"Parameter error">>, <<"from">>};
confirm_friend(_, _, undefined, _) ->
    {error, <<"Parameter error">>, <<"to">>};
confirm_friend(_, _, _, undefined) ->
    {error, <<"Parameter error">>, <<"payload">>};
confirm_friend(CurrentUid, From, To, Payload) ->
    FromID = imboy_hashids:uid_decode(From),
    ToID = imboy_hashids:uid_decode(To),
    NowTs = imboy_dt:millisecond(),
    Payload2 = jsone:decode(Payload, [{object_format, proplist}]),

    FromSetting = proplists:get_value(<<"from">>, Payload2),
    % Remark1 为 from 对 to 定义的 remark
    Remark1 = proplists:get_value(<<"remark">>, FromSetting),
    Source = proplists:get_value(<<"source">>, FromSetting),
    FromToIsFriend = friend_ds:is_friend(FromID, ToID),
    % 好友关系写入数据库
    friend_repo:confirm_friend(FromToIsFriend,
        FromID, ToID, Remark1, [{<<"isfrom">>, 1} | FromSetting], NowTs),

    ToSetting = proplists:get_value(<<"to">>, Payload2),
    ToFromIsFriend = friend_ds:is_friend(ToID, FromID),
    % Remark2 为 to 对 from 定义的 remark
    Remark2 = proplists:get_value(<<"remark">>, ToSetting),
    % 好友关系写入数据库
    friend_repo:confirm_friend(ToFromIsFriend,
        ToID, FromID, Remark2, [{<<"source">>, Source} | ToSetting], NowTs),

    % 因为是 ToID 通过API确认的，所以只需要给FromID 发送消息
    Id = <<"afc_", From/binary, "_", To/binary>>,
    MsgType = proplists:get_value(<<"msg_type">>, Payload2),
    Payload3 = confirm_friend_resp(ToID, Remark1),
    Payload4 = [{<<"isfrom">>, 1} | Payload3],
    Payload5 = [{<<"source">>, Source} | Payload4],
    Payload6 = [{<<"msg_type">>, MsgType} | Payload5],

    % 存储消息
    msg_s2c_ds:write_msg(NowTs, Id, Payload6, CurrentUid, FromID, NowTs),

    Msg = [{<<"id">>, Id},
        {<<"type">>, <<"S2C">>},
        % 这里的需要对调，离线消息需要对调
        {<<"from">>, To},
        {<<"to">>, From},
        {<<"payload">>, Payload6},
        {<<"server_ts">>, NowTs}
    ],
    % ?LOG(Msg),
    MsLi = [0, 1500, 1500, 3000, 5000, 7000],
    message_ds:send_next(FromID, Id, jsone:encode(Msg, [native_utf8]), MsLi),
    {ok, FromID, Remark2, Source}.


confirm_friend_resp(Uid, Remark) ->
    Column = <<"`id`,`account`,`nickname`,`avatar`,`gender`,`sign`,`region`,`status`">>,
    User = user_logic:find_by_id(Uid, Column),
    [{<<"remark">>, Remark} | imboy_hashids:replace_id(User)].

-spec delete_friend(CurrentUid::integer(), UID::binary()) -> ok.
delete_friend(CurrentUid, UID) ->
    friend_repo:delete(CurrentUid, imboy_hashids:uid_decode(UID)),
    ok.

%%% 查找非好友
search(Uid) ->
    % 只能够搜索“用户被允许搜索”的用户
    %
    FriendIDs = friend_ids(Uid),
    Info = FriendIDs,
    Info.


move_to_category(CurrentUid, Uid, CategoryId) ->
    friend_repo:move_to_category(CurrentUid, Uid, CategoryId),
    ok.


information(CurrentUid, Uid) ->
    ?LOG([CurrentUid, Uid]),
    Info = [],
    Info.


friend_list(Uid) ->
    Column = <<"`to_user_id`,`remark`,`setting`,`category_id`">>,
    case friend_ds:find_by_uid(Uid, Column) of
        [] ->
            [];
        Friends ->
            FriendItems = [
                {Id, {Remark, Cid, jsone:decode(S1, [{object_format, proplist}])}} || [
                    {<<"to_user_id">>, Id},
                    {<<"remark">>, Remark},
                    {<<"setting">>, S1},
                    {<<"category_id">>, Cid}] <- Friends],
            % ?LOG(Friends),
            Uids = [Id || {Id, _} <- FriendItems],
            Users = user_logic:find_by_ids(Uids),
            % 替换朋友备注信息
            Users2 = [filter_friend({Id, Row}, FriendItems, false) ||
                         [{<<"id">>, Id} | _] = Row <- Users],
            % 获取用户在线状态
            [user_logic:online_state(User) || {_Id, User} <- Users2]
    end.


category_friend(Uid) ->
    Column = <<"`to_user_id`,`remark`,`setting`,`category_id`">>,
    case friend_ds:find_by_uid(Uid, Column) of
        [] ->
            [];
        Friends ->
            FriendItems = [
                {Id, {Remark, Cid, jsone:decode(S1, [{object_format, proplist}])}} || [
                    {<<"to_user_id">>, Id},
                    {<<"remark">>, Remark},
                    {<<"setting">>, S1},
                    {<<"category_id">>, Cid}] <- Friends],
            % ?LOG(Friends),
            Uids = [Id || {Id, _} <- FriendItems],
            Users = user_logic:find_by_ids(Uids),
            % 替换朋友备注信息
            Users2 = [filter_friend({Id, Row}, FriendItems, true) ||
                         [{<<"id">>, Id} | _] = Row <- Users],
            % 获取用户在线状态
            Users3 = [{Id, user_logic:online_state(User)} ||
                         {Id, User} <- Users2],
            % 把用户归并到相应的分组
            Groups = friend_category_ds:find_by_uid(Uid),
            [append_group_list(G, Users3) || G <- Groups]
    end.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

%% 把用户归并到相应的分组
append_group_list(Group, Users) ->
    {<<"id">>, Cid} = lists:keyfind(<<"id">>, 1, Group),
    List = [User || {Id, User} <- Users, Cid == Id],
    [{<<"list">>, List} | Group].


%% 替换朋友备注信息
filter_friend({Uid, Row}, FriendItems, Replace) ->
    case lists:keyfind(Uid, 1, FriendItems) of
        {Uid, {<<>>, Cid, null}} ->
            Row2 = [{<<"remark">>, <<"">>} | Row],
            Row3 = [{<<"source">>, <<"">>} | Row2],
            Row4 = [{<<"isfrom">>, 0} | Row3],
            {Cid, Row4};
        {Uid, {<<>>, Cid, Setting}} ->
            Isfrom = proplists:get_value(<<"isfrom">>, Setting, 0),
            Source = proplists:get_value(<<"source">>, Setting, <<"">>),
            Row2 = [{<<"remark">>, <<"">>} | Row],
            Row3 = [{<<"source">>, Source} | Row2],
            Row4 = [{<<"isfrom">>, Isfrom} | Row3],
            {Cid, Row4};
        {Uid, {Remark, Cid, null}} ->
            Row2 = [{<<"remark">>, Remark} | Row],
            Row3 = [{<<"source">>, <<"">>} | Row2],
            Row4 = [{<<"isfrom">>, 0} | Row3],
            {Cid, Row4};
        {Uid, {<<>>, Cid, Setting}} ->
            Isfrom = proplists:get_value(<<"isfrom">>, Setting, 0),
            Source = proplists:get_value(<<"source">>, Setting, <<"">>),
            Row2 = [{<<"remark">>, <<"">>} | Row],
            Row3 = [{<<"source">>, Source} | Row2],
            Row4 = [{<<"isfrom">>, Isfrom} | Row3],
            {Cid, Row4};
        {Uid, {Remark, Cid, Setting}} when Replace =:= true ->
            Row1 = lists:keyreplace(<<"account">>,
                                    1,
                                    Row,
                                    {<<"account">>, Remark}),
            Isfrom = proplists:get_value(<<"isfrom">>, Setting, 0),
            Source = proplists:get_value(<<"source">>, Setting, <<"">>),
            Row2 = [{<<"remark">>, Remark} | Row1],
            Row3 = [{<<"source">>, Source} | Row2],
            Row4 = [{<<"isfrom">>, Isfrom} | Row3],
            {Cid, Row4};
        {Uid, {Remark, Cid, Setting}} ->
            Isfrom = proplists:get_value(<<"isfrom">>, Setting, 0),
            Source = proplists:get_value(<<"source">>, Setting, <<"">>),
            Row2 = [{<<"remark">>, Remark} | Row],
            Row3 = [{<<"source">>, Source} | Row2],
            Row4 = [{<<"isfrom">>, Isfrom} | Row3],
            {Cid, Row4}
    end.


friend_ids(Uid) ->
    Column = <<"`to_user_id`">>,
    case friend_ds:find_by_uid(Uid, Column) of
        [] ->
            [];
        Friends ->
            [ID || [{<<"to_user_id">>, ID}] <- Friends]
    end.
