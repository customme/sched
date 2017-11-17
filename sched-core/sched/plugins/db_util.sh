# 数据库工具


# 获取源数据库连接
function get_src_db()
{
    if [[ -z "$src_db_id" ]]; then
        error "Empty source database id"
        exit 1
    fi

    debug "Get source database by id: $src_db_id"
    src_db=($(get_db $src_db_id))
    if [[ -z "${src_db[@]}" ]]; then
        error "Can not find source database by id: $src_db_id"
        exit 1
    fi
    debug "Got source database: ${src_db[@]}"
}

# 获取目标数据库连接
function get_tar_db()
{
    if [[ -z "$tar_db_id" ]]; then
        error "Empty target database id"
        exit 1
    fi

    debug "Get target database by id: $tar_db_id"
    tar_db=($(get_db $tar_db_id))
    if [[ -z "${tar_db[@]}" ]]; then
        error "Can not find target database by id: $tar_db_id"
        exit 1
    fi
    debug "Got target database: ${tar_db[@]}"
}
