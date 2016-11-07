#!/usr/bin/expect

## 将[_xxx_] 替换成你自己实际的账户信息

set addr [_your_name_]@relay00.idcvdian.com
set password [_your_password_]
set decode_key [ exec sh -c {curl -s http://10.1.100.231:8080/decode.do?secret_key=[_your_secret_code_on_http://wdren.vdian.net/user/initDynamicKey]} ]

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