%%%-------------------------------------------------------------------
%%% @author Irfan Ali
%%% @doc
%%%
%%% @end
%%% Created : 04 Sept 2020 12:14:05
%%%-------------------------------------------------------------------
-module(mod_offline_http_post_notify).
-author("Mirza Irfan Ali").

-behaviour(gen_mod).

-export([start/2, stop/1, 
        depends/2,
        mod_options/1,
        mod_opt_type/1,
        mod_doc/0,
        create_message/1,
        create_message/3,
        muc_filter_message/3]).

-ifndef(LAGER).
-define(LAGER, 1).
-endif.

-include("xmpp.hrl").
-include("logger.hrl").
-include("mod_muc_room.hrl").
-include("mod_mam.hrl").

start(_Host, _Opt) ->
  ?INFO_MSG("mod_offline_http_post_notify loading", []),
  inets:start(),
  ?INFO_MSG("HTTP client started", []),
  ejabberd_hooks:add(muc_filter_message, _Host, ?MODULE, muc_filter_message, 100),
  ejabberd_hooks:add(offline_message_hook, _Host, ?MODULE, create_message, 100),
  ok.

stop(_Host) ->
  ?INFO_MSG("stopping mod_offline_http_post_notify", []),
  ejabberd_hooks:delete(muc_filter_message, _Host, ?MODULE, muc_filter_message, 100),
  ejabberd_hooks:delete(offline_message_hook, _Host, ?MODULE, create_message, 100),
  ok.


depends(_Host, _Opts) ->
  [].

mod_options(_Host) ->
  [{auth_token, <<"secret">>},
  {post_url, <<"http://example.com/notify">>},
  {confidential, false}].

mod_opt_type(auth_token) ->
  fun iolist_to_binary/1;
mod_opt_type(post_url) ->
  fun iolist_to_binary/1;
mod_opt_type(confidential) ->
  fun (B) when is_boolean(B) -> B end.

create_message({Action, Packet} = Acc) when (Packet#message.type == chat) and (Packet#message.body /= []) ->
  [{text, _, Body}] = Packet#message.body,
  StanzaMessageId = maps:get(stanza_id, Packet#message.meta),
  post_offline_message(Packet#message.from, Packet#message.to, Body, Packet#message.id, StanzaMessageId),
  Acc;

create_message(Acc) ->
  Acc.

create_message(_From, _To, Packet) when (Packet#message.type == chat) and (Packet#message.body /= []) ->
  Body = fxml:get_path_s(Packet, [{elem, list_to_binary("body")}, cdata]),
  MessageId = fxml:get_tag_attr_s(list_to_binary("id"), Packet),
  StanzaMessageId = maps:get(stanza_id, Packet#message.meta),
  post_offline_message(_From, _To, Body, MessageId, StanzaMessageId),
  ok.

post_offline_message(From, To, Body, MessageId, StanzaMessageId) ->
  Token = gen_mod:get_module_opt(To#jid.lserver, ?MODULE, auth_token),
  PostUrl = gen_mod:get_module_opt(To#jid.lserver, ?MODULE, post_url),
  ToUser = To#jid.luser,
  FromUser = From#jid.luser,
  Vhost = To#jid.lserver,

  Sep = "&",
  case gen_mod:get_module_opt(To#jid.lserver, ?MODULE, confidential) of
    true -> 
      Post = [
          "type=chat", Sep,
          "to=", ToUser, Sep,
          "from=", FromUser, Sep,
          "vhost=", Vhost, Sep,
          "messageId=", MessageId, Sep,
          "stanzaMessageId=", integer_to_list(StanzaMessageId), Sep 
      ];
    false -> 
      Post = [
          "type=chat", Sep,
          "to=", ToUser, Sep,
          "from=", FromUser, Sep,
          "vhost=", Vhost, Sep,
          "messageId=", MessageId, Sep,
          "stanzaMessageId=", integer_to_list(StanzaMessageId), Sep,
          "body=", Body, Sep
      ]
  end,
  ?DEBUG("Sending post request to ~s with body \"~s\"", [PostUrl, Post]),
  Request = {binary_to_list(PostUrl), [{"Authorization", binary_to_list(Token)}], "application/x-www-form-urlencoded", list_to_binary(Post)},
  httpc:request(post, Request,[],[]),
  ?DEBUG("post request sent", []).

-spec muc_filter_message(message(), mod_muc_room:state(), binary()) -> message().

muc_filter_message(Packet, #state{jid = RoomJID} = MUCState, FromNick) ->
    FromJID = xmpp:get_from(Packet),
    Token = gen_mod:get_module_opt(FromJID#jid.lserver, ?MODULE, auth_token),
    PostUrl = gen_mod:get_module_opt(FromJID#jid.lserver, ?MODULE, post_url),
    Vhost = FromJID#jid.lserver,
    BodyTxt = xmpp:get_text(Packet#message.body),
    MessageId = Packet#message.id,
    StanzaMessageId = maps:get(stanza_id, Packet#message.meta),

    _LISTUSERS = lists:map(
        fun({Uname, _Domain, _Res}) ->
            binary_to_list(Uname)
        end,
        maps:keys(MUCState#state.users)
    ),

    _AFILLIATIONS = lists:map(
        fun({Uname, _Domain, _Res}) ->
            binary_to_list(Uname)
        end,
        maps:keys(MUCState#state.affiliations)
    ),

    _OFFLINE = lists:subtract(_AFILLIATIONS, _LISTUSERS),
    ?DEBUG(" #########    GROUPCHAT _OFFLINE = ~p~n  #######   ", [_OFFLINE]),

    if
        BodyTxt /= "", length(_OFFLINE) > 0 ->
            Sep = "&",
            case gen_mod:get_module_opt(FromJID#jid.lserver, ?MODULE, confidential) of
              true -> 
                Post = [
                    "type=groupchat", Sep,
                    "to=", RoomJID#jid.luser, Sep,
                    "from=", FromJID#jid.luser, Sep,
                    "offline=", string:join(_OFFLINE, "|"), Sep,
                    "nick=", FromNick, Sep,
                    "vhost=", Vhost, Sep,
                    "messageId=", MessageId, Sep,
                    "stanzaMessageId=", integer_to_list(StanzaMessageId), Sep                 
                ];
              false -> 
                Post = [
                    "type=groupchat", Sep,
                    "to=", RoomJID#jid.luser, Sep,
                    "from=", FromJID#jid.luser, Sep,
                    "offline=", string:join(_OFFLINE, "|"), Sep,
                    "nick=", FromNick, Sep,
                    "vhost=", Vhost, Sep,
                    "messageId=", MessageId, Sep,
                    "stanzaMessageId=", integer_to_list(StanzaMessageId), Sep,
                    "body=", BodyTxt, Sep
                ]
            end,
            ?DEBUG("Sending post request to ~s with body \"~s\"", [PostUrl, Post]),
            Request = {binary_to_list(PostUrl), [{"Authorization", binary_to_list(Token)}], "application/x-www-form-urlencoded", list_to_binary(Post)},
            httpc:request(post, Request,[],[]),
            ?DEBUG("post request sent", []),
            Packet;
        true ->
            Packet
    end.

mod_doc() ->
    #{desc =>
          "This module implements for sending push notification. Now you can send push notification 1-1 chat or group chat. Tested and compatible with latest version of ejabberd 20.x",
      opts =>
          [{auth_token,
            #{value => "auth_token",
              desc =>
                  "This is for API call to authenticate"}},
           {post_url,
            #{value => "https://example.com/notify",
              desc =>
                  "Endpoint for capturing offline messages and users."}},
           {confidential,
            #{value => "true | false",
              desc =>
                  "If the value is 'true', message id not included"}}]}.