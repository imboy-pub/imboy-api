# imboy

基于 [cowboy](https://github.com/ninenines/cowboy)(Small, fast, modern HTTP server for Erlang/OTP) 的即时聊天后端服务，使用 "阿里云8核16G ecs.sn1ne.2xlarge主机（100万PPS）"压测，保持100万+TCP，90分钟以上，详细测试件[测试文档](test/doc/test1.md)

因为我是中国人，所以选择了[木兰宽松许可证, 第2版](https://gitee.com/imboy-pub/imboy-flutter/blob/main/LICENSE)


一些功能的设计思考权衡过程，请参考[文档](./doc/design_thinking.md)

## Version
力求基于“语义化版本控制的规范”([语义化版本 2.0.0](https://semver.org/lang/zh-CN/))实施版本管理.

Strive to implement version management based on "Specification for Semantic version Control"([Semantic Versioning 2.0.0](https://semver.org/)).

## 环境依赖  (Environment depends on)

数据结构(./doc/postgresql/vsn0.1)开发中有变动，以第一个发布版为准；目前改成基于 PostgreSQL15 开发

There are changes in the data structure (./doc/postgresql/vsn0.1) under development. It is currently based on PostgreSQL15

------

[more](./doc/deps_service.md)

Erlang/OTP 23 / Erlang/OTP 24 / Erlang/OTP 25

数据库 PostgreSQL15

### kerl
```
// 列表可安装的版本号
kerl list releases

kerl build 24.3.4.2 / kerl delete build 24.3.3

kerl list builds

kerl install 24.3.4.2 ~/kerl/24.3.4.2

. /Users/leeyi/kerl/24.3.4.2/activate

Later on, you can leave the installation typing:
kerl_deactivate

Anytime you can check which installation, if any, is currently active with:
kerl active
```

## [Using templates](https://erlang.mk/guide/getting_started.html)
```

make new t=cowboy.middleware n=demo_middleware
make new t=cowboy.middleware n=verify_middleware
make new t=gen_server n=account_server

make distclean

// 我添加的模板 以imboy开头
make new t=imboy.rest_handler n=demo_handler
make new t=imboy.logic n=demo_logic
make new t=imboy.repository n=demo_repo
make new t=imboy.ds n=demo_ds

make new t=imboy.rest_handler n=demo2_handler && make new t=imboy.logic n=demo2_logic && make new t=imboy.repository n=demo2_repo

make list-templates

make new-lib in=common
make new-lib in=cron
make new t=imboy.logic n=demo_cron_logic in=cron
...

make run

// on Mac
IMBOYENV=prod make run
IMBOYENV=test make run
IMBOYENV=dev make run
IMBOYENV=local make run

make rel IMBOYENV=local

// on CentOS8 OR macOS
export IMBOYENV='local' && make run

observer_cli:start().

make new t=gen_server n=server_demo

// 重新加载 sys.config 配置
config_ds:local_reload()

Routes = imboy_router:get_routes(),
Dispatch = cowboy_router:compile(Routes),
cowboy:set_env(imboy_listener, dispatch, Dispatch).

make dialyze
```


## make

```

// 小心！这将构建该文件，即使它之前已经存在。
make rebar.config

make rel

make help
  rel           Build a release for this project, if applicable
```

在另一个shelll里面执行
```
erl> help().
    lm()       -- load all modified modules

// 更新 erlang.mk
make erlang-mk

```

## Many applications in one repository
```
make new-app in=webchat
```

## edoc
link http://erlang.org/doc/apps/edoc/chapter.html#Introduction
```
```

## test
```
```

## 分析工具  (Analysis tool)
* [Dialyzer](https://erlang.mk/guide/dialyzer.html)
* [Look Glass](https://github.com/rabbitmq/looking_glass)

```
make dialyze

代码格式工具
get from https://github.com/sile/efmt/releases

VERSION=0.14.1
curl -L https://github.com/sile/efmt/releases/download/${VERSION}/efmt-${VERSION}.x86_64-unknown-linux-musl -o efmt
chmod +x efmt
./efmt

./efmt -c src/websocket_logic.erl
./efmt -w src/websocket_logic.erl
```


# 发布  (Release)
```
IMBOYENV=prod make rel
IMBOYENV=test make rel
IMBOYENV=dev make rel -j8
IMBOYENV=local make rel
```

复制代码到特定的目录  (Copy code to a specific directory)

```
cp ./_rel/imboy/imboy-1.0.0.tar.gz
// or
scp ./_rel/imboy/imboy-1.0.0.tar.gz root@192.168.2.207:/usr/local/imboy/

```

去启动服务  (To start the service)

```

mkdir -p /usr/local/imboy

cp ./_rel/imboy/imboy-1.0.0.tar.gz /usr/local/imboy/

cd /usr/local/imboy

tar -xzf imboy-1.0.0.tar.gz

bin/imboy console

bin/imboy start

bin/imboy restart

bin/imboy stop
```

## 更新发布  (updates)

link https://erlang.mk/guide/relx.html
```
IMBOYENV=prod make relup
```

For the purpose of this section, assume the initial release version was 1, and the new version is 2. The name of the release will be example.

Once all this is done, you can build the tarball for the release upgrade:
```
$ make relup
```
This will create an archive at the root directory of the release, $RELX_OUTPUT_DIR/example/example-2.tar.gz.

Move the archive to the correct location on the running node. From the release’s root directory:
```
$ mkdir releases/2/
$ mv path/to/example-2.tar.gz releases/2/
```

Finally, upgrade the release:
```
$ bin/example_release upgrade "2/example_release"

scp ./_rel/imboy/imboy-0.1.1.tar.gz root@120.24.63.33:/usr/local/imboy

mv imboy-0.1.1.tar.gz releases/0.1.1/
bin/imboy upgrade "0.1.1/imboy"

bin/imboy downgrade "0.1.0/imboy"

```
Your release was upgraded!

## [Updating Erlang.mk](https://erlang.mk/guide/updating.html#_initial_bootstrap)
```
make erlang-mk
```

## imboy.appup
```
{"0.2.0",
    所有版本"0.1.*"升级到版本"0.2.0",重启应用
   [{"0.1\\.[0-9]+", [{restart_application, imboy_app}
             ]}],
    版本"0.2.0"降级到所有版本"0.1.*",重启应用
   [{"0.1\\.[0-9]+", [{restart_application, imboy_app}
             ]}]
}.
```

# api 约定  (api convention)
* [API参考](./doc/API定义.md)
* [消息格式参考](./doc/消息类型.md)


# erlang 优化
```
+K true
开启epoll调度，在linux中开启epoll，会大大增加调度的效率

+A 1024
异步线程池，为某些port调用服务

+P 2048000
最大进程数

+Q 2048000
最大port数

+sbt db
绑定调度器，绑定后调度器的任务队列不会在各个CPU线程之间跃迁，结合sub使用，可以让CPU负载均衡的同时也避免了大量的跃迁发生。

注意：一个linux系统中，最好只有一个evm开启此选项，若同时有多个erlang虚拟机在系统中运行，还是关闭为好


+sub true
开启CPU负载均衡，false的时候是采用的CPU密集调度策略，优先在某个CPU线程上运行任务，直到该CPU负载较高为止。

+swct eager
此选项设置为eager后，CPU将更频繁的被唤醒，可以增加CPU利用率

+spp true
开启并行port并行调度队列，当开启后会大大增加系统吞吐量，如果关闭，则会牺牲吞吐量换取更低的延迟。

+zdbbl 65536
分布式erlang的端口buffer大小，当buffer满的时候，向分布式的远程端口发送消息会阻塞

```

# 压力测试

```

打开文件数 for mac
sudo launchctl limit maxfiles
sudo launchctl limit maxfiles 2097152 2097152
sudo ulimit -n 2097152

sysctl net.inet.ip.portrange.first net.inet.ip.portrange.last

## 及高范围
net.inet.ip.portrange.hifirst: 49152
net.inet.ip.portrange.hilast: 65535

sysctl -w net.inet.ip.portrange.first=1025
sysctl -w net.inet.ip.portrange.last=655350
sysctl -w net.inet.ip.tcp_rmem=655350


HAProxy + Docker * N + K8S + mnesia 集群
erlang:system_info(port_limit).

locust -f src/imboy.py --no-web -c 20000 -r 1000 -t 600s --logfile=logs/imboy-no-web.log
length(chat_store_repo:lookall()).

参考：

http://m.udpwork.com/item/11782.html
https://cloud.tencent.com/developer/article/1422476
https://www.yuanmomo.net/2019/07/26/mac-max-connections-config/
https://colobu.com/2014/09/18/linux-tcpip-tuning/

https://www.cnblogs.com/duanxz/p/4464178.html 单服务器最大tcp连接数及调优汇总

https://blog.51cto.com/yaocoder/1312821

http://hk.uwenku.com/question/p-tgiqupmb-oc.html

https://knowledge.zhaoweiguo.com/8tools/mqtts/emqtts/emqtt_tune.html

https://studygolang.com/articles/2416

https://www.iteye.com/blog/mryufeng-475003  erlang 节点间通讯的通道微调

http://www.wangxingrong.com.cn/archives/tag/百万并发连接服务器

https://qunfei.wordpress.com/2016/09/20/from-c10k-to-c100k-problem-push-over-1000000-messages-to-web-clients-on-1-machine-simultaneously/

https://stackoverflow.com/questions/32711242/erlang-simultaneously-connect-1m-clients

https://colobu.com/2015/05/22/implement-C1000K-servers-by-spray-netty-undertow-and-node-js

https://blog.csdn.net/zcc_0015/article/details/26407683 Linux下基于Erlang的高并发TCP连接压力实验

https://github.com/smallnest/C1000K-Servers

100万并发连接服务器笔记之Erlang完成1M并发连接目标 https://blog.csdn.net/shallowgrave/article/details/19990345?utm_medium=distribute.pc_relevant.none-task-blog-BlogCommendFromBaidu-5.nonecase&depth_1-utm_source=distribute.pc_relevant.none-task-blog-BlogCommendFromBaidu-5.nonecase
```

docker run -it --rm --name imboy-1 -p 9801:9800 -v "$PWD":/usr/src/imboy -w /usr/src/imboy erlang

// 后台运行
docker-compose up -d
docker-compose -f docker-local.yml up -d


下面的命令增加了19个IP地址，其中一个给服务器用
sudo ifconfig lo0 alias 127.0.0.10
sudo ifconfig lo0 alias 127.0.0.11
length(chat_store_repo:lookall()).

sudo ifconfig lo0 -alias 127.0.0.10
sudo ifconfig lo0 -alias 127.0.0.11

 Erlang虚拟机默认的端口上限为65536, erlang17通过erl +Q 1000000可以修改端口上限为1000000,利用erlang:system_info(port_limit)进行查询，系统可以打开的最大文件描述符可以通过erlang:system_info(check_io)中的max_fds进行查看，查看系统当前port数量可以用erlang:length(erlang:ports())得到

erlang:system_info(port_limit)
erlang:system_info(check_io)
erlang:length(erlang:ports()).

Pid = spawn(fun() -> etop:start([{output, text}, {interval, 1}, {lines, 20}, {sort, memory}]) end).

```
查看TCP 数量
netstat -n | awk '/^tcp/ {++S[$NF]} END {for(a in S) print a, S[a]}'
ESTABLISHED 28705

free -h
              total        used        free      shared  buff/cache   available
Mem:           3.7G        2.8G        774M        452K        140M        726M
Swap:            0B          0B          0B

查看 pid
 pmap -d 6380
```
erl -name ws2@127.0.0.1 -setcookie imboy -hidden
net_adm:ping('imboy@127.0.0.1').
Ctrl + G
h
r 'imboy@127.0.0.1'
j
c 2

cowboy_websocket 异步消息
websocket close 传递参数

如何动态加载配置文件
```
ifeq ($(ENV),prod)
    RELX_CONFIG = $(CURDIR)/relx.prod.config
else ifeq ($(ENV),test)
    RELX_CONFIG = $(CURDIR)/relx.test.config
else ifeq ($(ENV),dev)
    RELX_CONFIG = $(CURDIR)/relx.dev.config
else ifeq ($(ENV),local)
    RELX_CONFIG = $(CURDIR)/relx.local.config
else
    RELX_CONFIG ?= $(CURDIR)/relx.config
endif
```


## cowboy Live update
```
Routes = imboy_router:get_routes(),
Dispatch = cowboy_router:compile(Routes),
cowboy:set_env(imboy_listener, dispatch, Dispatch).
```

## reload sys.config
```
config_ds:reload().
config_ds:local_reload()
```

## erlang 的shell 访问远程节
```
erl -name debug@127.0.0.1
auth:set_cookie('imboy'),net_adm:ping('imboy@127.0.0.1').
net_adm:names().
{ok,[{"imboy",55042},{"debug",60595}]}

按 Ctrl+G 出现user switch command
然后输入

r 'imboy@127.0.0.1'

按回车

在按 J 机器显示节点:
 --> j
   1  {shell,start,[init]}
   2* {'imboy@127.0.0.1',shell,start,[]}

在 * 的就是默认的可连接节点，其中的1 行，就是你现在的master节点

按 c 就能连接

你如果要连接到第三节点的话，直接 输入 c 6 回车就行了。

chat_store_repo:lookup(1).

curl -L https://github.com/sile/erldash/releases/download/0.1.1/erldash-0.1.1.x86_64-unknown-linux-musl -o erldash
chmod +x erldash
./erldash imboy@127.0.0.1 -c imboy


```

## webrtc


## websocket 在线工具调试

为了简化代码取消WS了在线调试（如有必要，以后可以看情况添加一个h5页面做调试工具）

http://coolaf.com/tool/chattest
io:format("~p~n", [token_ds:encrypt_token(4)]).

```
(imboy@127.0.0.1)10>  hashids_translator:uid_encode(4).
<<"8ybk5b">>
(imboy@127.0.0.1)11> hashids_translator:uid_encode(1).
<<"kybqdp">>
{"id":"text5","type":"C2C","from":"8ybk5b","to":"kybqdp","payload":{"msg_type":"text","text":"text5"},"created_at":1650118822382,"server_ts":1650118823376}
```

## Email
```
gen_smtp_client:send({"sender@gmail.com", ["receiver@gmail.com"], "Subject: testing"},
   [{relay, "smtp.gmail.com"}, {ssl, true}, {username, "sender@gmail.com"},
      {password, "senderpassword"}]).

```

## imboy_cache.erl

copy from https://github.com/zotonic/zotonic/blob/master/apps/zotonic_core/src/support/z_depcache.erl

* 为了项目风格统一，并且不依赖 zotonic.hrl ，所以修改了module名称
* The Module name was changed in order to maintain a uniform project style and not rely on zotonic.hrl

```
imboy_cache:set(a, 1).
imboy_cache:get(a).
imboy_cache:memo(fun() ->
    a
end).
```

## imboy_session

```
imboy_session:join(1, <<"ios">>, spawn(fun() -> receive _ -> ok end end), <<"did11">>).
imboy_session:join(1, <<"andriod">>, spawn(fun() -> receive _ -> ok end end), <<"did12">>).
imboy_session:join(1, <<"macos">>, self(), <<"3f039a2b4724a5b7">>).

imboy_session:join(2, <<"ios">>, spawn(fun() -> receive _ -> ok end end), <<"did21">>).
imboy_session:join(2, <<"andriod">>, spawn(fun() -> receive _ -> ok end end), <<"did22">>).
imboy_session:join(3, <<"andriod">>, spawn(fun() -> receive _ -> ok end end), <<"did32">>).

imboy_session:count().
imboy_session:count_user().
imboy_session:count_user(1).
imboy_session:list(1).

syn:

ets:select(syn_pg_by_name_chat, [{ '$1', [], ['$1']}]).
ets:select(syn_pg_by_name_chat, [{ '$1', [], ['$1']}], 10).
```

## eturnal
```
cd /www/wwwroot/eturnal/

_build/product/rel/eturnal/bin/eturnal console

 _build/product/rel/eturnal/bin/eturnal daemon
```

## 消息确认机制
服务端，发送消息代码如下：
```
    MillisecondList = [0, 1500, 1500, 3000, 1000, 3000, 5000],
    message_ds:send_next(Uid, DType, MsgId, Msg, MillisecondList),
```
* MillisecondList 频率控制列表，列表元素以单位为毫秒；
    * 0 标识第1条消息马上发送；
    * 1500 表示，消息1500毫米内没有ack，的情况下会再次投递
    * 其他逻辑元素逻辑如上
* Uid 用户ID
* MsgId 消息ID，消息唯一标识
* Msg 消息json文本

客户端收到消息后发送以下文本数据(对erlang来说是binary文本)，用于消息收到确认
```
CLIENT_ACK,type,msgid,did
```
4段信息以半角逗号（ , ）分隔：

* 第1段： CLIENT_ACK 为固定消息确认前缀
* 第2段： type 是IM消息类型
* 第3段： msgid 消息唯一ID
* 第4段： did 登录用户设备ID


测试验证数据，收到测试观察，该消息确认机制有效
```
http://coolaf.com/tool/chattest

ws://192.168.1.4:9800/ws/?authorization=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2Njg1Njk3MTY0MDksInN1YiI6InRrIiwidWlkIjoiYnltajVnIn0.zPojzN6IfxzIfU4CCJodguaAMcGPDx3XLTvou6-U9A8

CLIENT_ACK,type,msgid,did

CurrentUid = 13238,
MsgId = <<"msgid">>,
DID = <<"did">>.
webrtc_ws_logic:event(13238, <<"ios">>, MsgId, <<"Msg bin">>).


http://coolaf.com/tool/chattest

// 1
ws://192.168.1.4:9800/ws/?authorization=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2NjExMDM5NDQ5MTgsInN1YiI6InRrIiwidWlkIjoia3licWRwIn0.FYhYR0KzHZe9kHEeTbcYWwahyqLXBE7rUWaQgyI5I14

1 = imboy_hashids:uid_decode("kybqdp").
108 = imboy_hashids:uid_decode("7b4v1b").
{"id":"cdsgrbgppoodp0gvpb60","type":"C2C","from":"kybqdp","to":"7b4v1b","payload":{"msg_type":"text","text":"1to108"},"created_at":1668877742828}

108
ws://192.168.1.4:9800/ws/?authorization=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2NjkwNDc2Nzc3MDgsInN1YiI6InRrIiwidWlkIjoiN2I0djFiIn0.n19M6-kR_p4EtqJMst4kO1cqgdG5F2gyNY6QL46xpR8
{"id":"cdsgrbgppoodp0gvpb61","type":"C2C","to":"kybqdp","from":"7b4v1b","payload":{"msg_type":"text","text":"108to1"},"created_at":1668877742828}
```

token_ds:decrypt_token(<<"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2OTQwNTI2NDEyNjQsInN1YiI6InJ0ayIsInVpZCI6IjlkNG5uayJ9.N7X7mpInEbiawIP7qiDOf00Gbmm4H-4HM2cAukQ-040">>).

{ok,513244,1694052641264,<<"rtk">>}

1694052641264 - imboy_dt:millisecond().
rtmp_proxy:run(1935, <<"rtmp://192.168.0.144/live_room">>).


rm -rf  /Users/leeyi/workspace/imboy/imboy/_rel/imboy/lib/wx-2.2.2/priv/wxe_driver.so && ln -s /opt/homebrew/Cellar/erlang@25/25.3.2.5/lib/erlang/lib/wx-2.2.2/priv/wxe_driver.so /Users/leeyi/workspace/imboy/imboy/_rel/imboy/lib/wx-2.2.2/priv/wxe_driver.so



