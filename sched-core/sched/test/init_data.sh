function execute_sql()
{
    local sql="$1"
    if [[ -z "$sql" ]]; then
        sql=`cat`
    fi

    echo "SET NAMES utf8;$sql" | mysql -h192.168.1.102 -uetl -p123456 zhenai_crm -s -N --local-infile
}

# 分表
function sub_table()
{
  # 创建分表
    range_num 0 9 | while read num; do
        echo "drop table if exists user_register_$num;
        create table user_register_$num(
        user_id int comment '用户ID',
        password varchar(64) comment '用户密码',
        realname varchar(32) comment '用户姓名',
        gender tinyint comment '性别',
        birthday date comment '生日',
        email varchar(64) comment '邮箱',
        address varchar(255) comment '地址',
        channel_id int comment '渠道ID',
        create_time datetime comment '创建时间',
        update_time datetime comment '更新时间',
        primary key(user_id)
        ) engine=MyISAM comment='用户注册表';"
    done | execute_sql

    # 创建总表
    tables=`range_num 0 8 | awk '{
        printf("user_register_%s,",$1)
    }END{
        print "user_register_9"
    }'`

    echo "drop table if exists user_register;
    create table user_register(
        user_id int comment '用户ID',
        password varchar(64) comment '用户密码',
        realname varchar(32) comment '用户姓名',
        gender tinyint comment '性别',
        birthday date comment '生日',
        email varchar(64) comment '邮箱',
        address varchar(255) comment '地址',
        channel_id int comment '渠道ID',
        create_time datetime comment '创建时间',
        update_time datetime comment '更新时间',
        primary key(user_id)
    ) ENGINE=MRG_MyISAM DEFAULT CHARSET=utf8 comment='用户注册表' UNION=(${tables});
    " | execute_sql

    # 插入数据
    range_num 1 10000 | awk '{
        user_id=int($1)
        sub_num=substr($1,length($1))
        realname="用户"$1
        gender=$1%2
        birthday="19880506 - interval "sub_num" day"
        email=$1"@163.com"
        address="广东省深圳市宝安区西乡街道"$1"号"
        printf("insert ignore into user_register_%s values(%s,\"%s\",\"%s\",%s,%s,\"%s\",\"%s\",%s,now(),now());\n",sub_num,user_id,$1,realname,gender,birthday,email,address,user_id)
    }' | execute_sql
}

# 月表
function month_table()
{
    # 创建分表
    range_date 201401 201407 | while read the_month; do
        echo "drop table if exists user_login_$the_month;
            create table user_login_$the_month(
            user_id int comment '用户ID',
            login_time datetime comment '登录时间',
            channel_id int comment '渠道',
            primary key(user_id,login_time)
        ) engine=MyISAM comment='用户登录表';"
    done | execute_sql

    # 插入数据
    range_date 2014010100 2014071018 | while read the_time; do
        echo "SELECT user_id,channel_id FROM user_register ORDER BY RAND() LIMIT 100;" |
        mysql -h192.168.1.100 -uetl -p123456 zhenai_crm |
        while read user_id channel_id; do
            echo "insert into user_login_${the_time:0:6} values 
            ($user_id,STR_TO_DATE(CONCAT('$the_time',date_format(now(),'%i%s')),'%Y%m%d%H%i%s'),$channel_id);"
        done | execute_sql
    done
}
