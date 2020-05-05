-module(passport_handler).
-behavior(cowboy_handler).

-export([init/2]).

-include("imboy.hrl").

init(Req0, State) ->
    ?LOG(['passport_handler',  Req0]),
    [Op | _] = State,
    case Op of
        do_login ->
            do_login(Req0)
    end.

do_login(Req0) ->
    %%%
    %%% 在POST请求中取出内容
    %%% 用户名ＮＡＭＥ
    %%% 密码 ＰＡＳＳＷＤ
    {ok, [{_A, Account} ,{_P, Password}, {_, RsaEncrypt}], _Req} = cowboy_req:read_urlencoded_body(Req0),
    Pwd = if
        RsaEncrypt == <<"1">> ->
            imboy_cipher:rsa_decrypt(Password);
        true ->
            Password
    end,
    case user_as:do_login(Account, Pwd) of
        {ok, Data} ->
            resp_json_dto:success(Req0, Data, "操作成功.");
        {error, Msg} ->
            resp_json_dto:error(Req0, Msg);
        {error, Msg, Code} ->
            resp_json_dto:error(Req0, Msg, Code)
    end.

