#!/usr/bin/expect

## 将[_xxx_] 替换成你自己的实际信息

set addr [_your_name_]@[_server_addr_]
set password [_your_password_]
set decode_key [ exec sh -c {curl -s http://[_decode_server_ip_]:8080/decode.do?secret_key=[_your_secret_code_]} ]

set timeout 30
spawn ssh $addr
expect {  
    "*Verification*" {  
        send "$decode_key\r"
        exp_continue
    }  
    "*Password*" {  
        send "$password\r"
    }
}
interact