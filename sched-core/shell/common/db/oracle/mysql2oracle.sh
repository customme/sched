# oracle到mysql数据类型转换


# 整型转换
# tinyint->number(3)
# smallint->number(5)
# mediumint->number(7)
# int/integer->number(10)
# bigint->number(19)
# numeric/year->number
function integer_conv()
{
    sed "s/ tinyint(.*)/ number(3)/ig;s/ smallint(.*)/ number(5)/ig;s/ mediumint(.*)/ number(7)/ig;s/ int(.*)\| integer/ number(10)/ig;s/ bigint(.*)/ number(19)/ig;s/ numeric\| year(.*)/ number/ig"
}

# 浮点型转换
# decimal/double/real->float(24)
function float_conv()
{
    sed "s/ decimal(.*)\| double.*\| real/ float(24)/ig"
}

# 字符型转换
# char->nchar
# varchar(1,3)->nvarchar2
# tinytext->nvarchar2(255)
# varchar(4,)/mediumtext/text/longtext->nvarchar2(4000)
# enum->nvarchar2(64)
# set->nvarchar2(255)
function string_conv()
{
    sed "s/ char/ nchar/ig;s/ varchar\(([0-9]\{1,3\})\)/ nvarchar2\1/ig;s/ tinytext/ nvarchar2(255)/ig;s/ varchar([0-9]\{4,\})\| mediumtext\| text\| longtext/ nvarchar2(4000)/ig;s/ enum(.*)/ nvarchar2(64)/ig;s/ set(.*)/ nvarchar2(255)/ig"
}

# 日期型转换
# datetime/time/timestamp->date
function date_conv()
{
    sed "s/ datetime\| time\| timestamp/ date/ig"
}

# mysql数据类型到oracle转换
function type_conv()
{
    integer_conv | float_conv | string_conv | date_conv
}
