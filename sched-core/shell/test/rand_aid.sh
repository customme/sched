#!/bin/bash
#
# 生成随机aid


# num 个数
# 例如生成100个随机字符串: rand_str 100
function rand_str()
{
    echo "$@" | awk 'BEGIN{
        srand()
    }{
        num=$1

        # 0-9 a-f
        for(i=1;i<=16;i++){
            if(i<=10){
                x[i] = i-1
            }else{
                x[i] = 97 + i - 11
            }
        }

        for(i=0;i<num;i++){
            a = int(10 * rand()) + int(10 * rand())
            if(a < 2){
                a = 2
            }else if(a > 16){
                a = 16
            }
            if(a <= 10){
                printf(x[a])
            }else{
                printf("%c",x[a])
            }

            # 16位占94% 15位占6%
            c = int(100 * rand())
            if(c > 5){
                digit = 16
            }else{
                digit = 15
            }

            for(j=1;j<digit;j++){
                b = int(10 * rand()) + int(10 * rand())
                if(b < 1){
                    b = 1
                }else if(b > 16){
                    b = 16
                }
                if(b <= 10){
                    printf(x[b])
                }else{
                    printf("%c",x[b])
                }
            }
            printf("\n")
        }
    }'
}

# 生成随机字符串
time(rand_str 1000000 > /tmp/aid.txt)

# 导入mysql表
time(mysql -h10.10.10.205 -P3308 -udw -pmysql adtest --local-infile -e "TRUNCATE TABLE t_androidid;LOAD DATA LOCAL INFILE '/tmp/aid.txt' IGNORE INTO TABLE t_androidid;")
