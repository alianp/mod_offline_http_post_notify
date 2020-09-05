# mod_offline_http_post_notify
Ejabberd 20.xx module to send one to one or group chat offline message to user's via POST request to target URL
This module can call an api to send e.g. a push message.
The request body is in application/x-www-form-urlencoded format. See the example below.

V20.xx
Updated and tested in 20.07, I assume it works from 19.05 onwards.

Installation
------------

1. cd /home/xxxxx/.ejabberd-module/sources/
2. git clone https://github.com/alianp/mod_offline_http_post_notify.git;
3. start ejabberd
4. bash /path-to-ejabberdctl/ejabberdctl module-install mod_offline_http_post_notify
5. restart ejabberd

That's it. The module is now installed.

Configuration
-------------

Add the following to ejabberd configuration under `modules:`

```
mod_offline_http_post_notify:
  auth_token: "source_validate"
  post_url: "http://example.com/notify"
  confidential: false
```

-    auth_token - user defined, hard coded token that will be sent as part of the request's body. Use this token on the target server to validate that the request arrived from a trusted source.
-    post_url - the server's endpoint url
-    confidential - boolean parameter; if true, do not send the message body in post data. if false (default), send the message body.

Example of the outgoing request:
--------------------------------

In one to one chat:
```
Array
(
    [type] => chat
    [to] => test2
    [from] => test1
    [vhost] => localhost
    [messageId] => purplee060f9e5
    [stanzaMessageId] => 1599283860553814
    [body] => dfsd
)
```
In group chat:
```
Array
(
    [type] => groupchat
    [to] => test_room
    [from] => test1
    [offline] => test2|test3
    [nick] => test1
    [vhost] => localhost
    [messageId] => purplee060f9f0
    [stanzaMessageId] => 1599284280003783
    [body] => sdf
)
```

NOTE:- offline user name with saperated by "|" pipe.
