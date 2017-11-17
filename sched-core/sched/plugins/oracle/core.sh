#oracle表定义
function make_oracle_def()
{
  cat ${task_data_path}/${table_name}.src_table.def |
  sed 's/UNIQUE //i;1d;$d;/ KEY /d;s/`//g' | awk '{
    gsub(",$","",$2)
    print $1,$2
  }' | oracle_keyword_conv | mysql_oracle_conv |
  awk 'BEGIN{
    print("create table '$tar_table_name'(")
  }{
    print $0","
  }END{
    print("ftime number(10)")
    print(")")
    print("partition by range(ftime)(")
    print("partition part_'$the_day' values less than('$next_day')")
    print(")")
  }' > ${task_data_path}/${table_name}.tar_table.oracle.def
}

#生成查询sql
function make_query_sql()
{
  local table_name="$1"
  local columns="$2"
  local time_columns="$3"
  local filter="$4"

  local sql="select $columns from $table_name where 1=1"

  if [ -n "$time_columns" ]; then
    sql=`echo "$time_columns" | awk -F"," '{
      for(i=1;i<=NF;i++){
        printf("%s and %s>='$prev_day' and %s<'$the_day' %s union all ",sql,$i,$i,filter)
      }
    }' sql="$sql" filter="$filter" | sed 's/ union all $//'`
  else
    sql="$sql $filter"
  fi

  echo "$sql;"
}