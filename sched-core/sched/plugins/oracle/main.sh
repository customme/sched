source common/plugins/mysql2oracle/core.sh

function main()
{
  db_url=$(make_db_url "${src_db[1]}" "${src_db[2]}" "${src_db[3]}" "${src_db[4]}" "${src_db[5]}")
  db_charset=${src_db[6]}
  get_table_def $table_name
  local sql=$(make_query_sql $table_name $src_columns $src_time_columns "$src_filter")
  execute_sql "$sql" "$db_url" > ${task_data_path}/${table_name}.tmp
}
main "$@"