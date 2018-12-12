#!/bin/bash


HOSTS="192.168.1.15
192.168.1.16
192.168.1.17
192.168.1.18
192.168.1.19
192.168.1.20
192.168.1.21
192.168.1.22
192.168.1.23
192.168.1.24
192.168.1.25"

USER=root
PASSWORD=1234567


function install()
{
    echo "$HOSTS" | while read host; do
        autossh "$PASSWORD" $USER@$host "rm -f anaconda-ks.cfg"
        autossh "$PASSWORD" $USER@$host "yum install -y net-tools vim lrzsz ntpdate wget dos2unix"
        autossh "$PASSWORD" $USER@$host "systemctl stop firewalld.service"
        autossh "$PASSWORD" $USER@$host "systemctl disable firewalld.service"
        autossh "$PASSWORD" $USER@$host "systemctl stop postfix.service"
        autossh "$PASSWORD" $USER@$host "systemctl disable postfix.service"
        autossh "$PASSWORD" $USER@$host "echo \"0 */4 * * * /usr/sbin/ntpdate 1.asia.pool.ntp.org;/usr/sbin/hwclock -w\" >> /var/spool/cron/root"
    done
}

function check_hostname()
{
    echo "$HOSTS" | while read host; do
        autossh "$PASSWORD" $USER@$host "hostname"
    done | awk '$0 ~ /\.com|^root@/ {if(NR %2 == 0){printf("%s\n",$0)}else{printf("%s\t",$0)}}'
}

function check_firewall()
{
    echo "$HOSTS" | while read host; do
        autossh "$PASSWORD" $USER@$host "systemctl status firewalld.service" | awk '$0 ~ /Active: / {print "'$host'",$0}'
    done
}

function clone_gitlab()
{
    ls -d /home/git/repositories/* | while read dir; do
        group=`basename $dir`
        find $dir -type d -name "*.git" | while read git; do
            project=`basename $git`
            echo "mkdir -p $group;git clone git@114.119.9.72:$group/$project $group"
        done
    done > clone_gitlab.sh
}

function export_gitlab()
{
    echo "SELECT name, path, description FROM namespaces WHERE type = 'Group';" | mysql -uroot gitlab -s -N |
    awk -F '\t' 'BEGIN{
        print ""
    }{
        printf("INSERT INTO namespaces (name, path, owner_id, created_at, type, description) VALUES ('\''%s\'\'', '\''%s'\'', 1, NOW(), '\''Group'\'', '\''%s'\'');\n",$1,$2,$3)
    }' | psql -h /var/opt/gitlab/postgresql -d gitlabhq_production | tr -s '\n'

    echo "SELECT name, path, created_at, namespace_id FROM projects;" | mysql -uroot gitlab -s -N |
    awk -F '\t' 'BEGIN{
        print ""
    }{
        printf("INSERT INTO projects (name, path, created_at, creator_id, namespace_id) VALUES ('\''%s'\'', '\''%s'\'', '\''%s'\'', 1, %d);\n",$1,$2,$3,$4)
    }' | psql -h /var/opt/gitlab/postgresql -d gitlabhq_production | tr -s '\n'
}

function curl_gitlab()
{
    login_url="http://192.168.1.19/users/sign_in"
    authenticity_token="bl1jzMtkuORnDAwX4SalL2YqLE1rcm8WjSf4BwuIR2zyS95rG1dKxqe33kaprEZKNssN4UNop4cz+hfTblauLs=="
    curl -s --connect-timeout 60 -c /tmp/cookie.tmp -X post -d "user[login]=root&user[password]=gitlab123&user[remember_me]=0&authenticity_token=$authenticity_token&utf8=✓" $login_url
}

function main()
{
    install

    check_hostname

    check_firewall
}
main