# postgresql工具


# 特殊字符转义
# (' ")
function pg_escape()
{
    sed "s/\('\|\"\)/\\\\\1/g"
}

# 初始化数据库配置
function init_pg_db()
{
    DEFAULT_PG_HOST=localhost
    DEFAULT_PG_PORT=5432
    DEFAULT_PG_USER=postgres
    DEFAULT_PG_PASSWD=123456
    DEFAULT_PG_NAME=postgres
    DEFAULT_PG_CHARSET=utf8
    DEFAULT_PG_EXTRAS="-q -t --no-align -F $'\t'"
    DEFAULT_PG_URL=$(make_pg_url)
}

# 执行sql语句
function pg_executor()
{
    local sql="$1"
    local db_url="$2"

    if [[ -z "$sql" ]]; then
        sql=`cat`
    fi

    # 设置默认数据库连接
    if [[ -z "$db_url" ]]; then
        db_url=$DEFAULT_PG_URL
    fi

    # 记录sql日志
    if [[ "$SQL_LOG" = "$SWITCH_ON" ]]; then
        if [[ -z "$sql_log_file" ]]; then
            local sql_log_file=${LOG_DIR:-.}/sql_$(date +%Y%m%d).log
        fi

        # 创建目录
        mkdir -p `dirname ${sql_log_file}`

        log "[ $sql ]" >> $sql_log_file
    fi

    echo "$sql" | psql $db_url | tr -s '\n'
}

# 生成连接字符串
function make_pg_url()
{
    local host="${1:-$DEFAULT_PG_HOST}"
    local user="${2:-$DEFAULT_PG_USER}"
    local passwd="${3:-$DEFAULT_PG_PASSWD}"
    local db="${4:-$DEFAULT_PG_NAME}"
    local port="${5:-$DEFAULT_PG_PORT}"
    local charset="${6:-$DEFAULT_PG_CHARSET}"
    local extras="${7:-$DEFAULT_PG_EXTRAS}"

    echo "$host:$port:$db:$user:$passwd" >> ~/.pgpass
    sort -u ~/.pgpass -o ~/.pgpass
    chmod 0600 ~/.pgpass

    echo "-h $host -p $port -U $user -d $db $extras"
}

# pg关键字加后缀
function pg_keyword_conv()
{
    sed 's/^\(A\|ABORT\|ABS\|ABSOLUTE\|ACCESS\|ACTION\|ADA\|ADD\|ADMIN\|AFTER\|AGGREGATE\|ALIAS\|ALL\|ALLOCATE\|ALSO\|ALTER\|ALWAYS\|ANALYSE\|ANALYZE\|AND\|ANY\|ARE\|ARRAY\|AS\|ASC\|ASENSITIVE\|ASSERTION\|ASSIGNMENT\|ASYMMETRIC\|AT\|ATOMIC\|ATTRIBUTE\|ATTRIBUTES\|AUTHORIZATION\|AVG\)\t/\1_\t/ig' |
    sed 's/^\(BACKWARD\|BEFORE\|BEGIN\|BERNOULLI\|BETWEEN\|BIGINT\|BINARY\|BIT\|BITVAR\|BIT_LENGTH\|BLOB\|BOOLEAN\|BOTH\|BREADTH\|BY\)\t/\1_\t/ig' |
    sed 's/^\(C\|CACHE\|CALL\|CALLED\|CARDINALITY\|CASCADE\|CASCADED\|CASE\|CAST\|CATALOG\|CATALOG_NAME\|CEIL\|CEILING\|CHAIN\|CHAR\|CHARACTER\|CHARACTERISTICS\|CHARACTERS\|CHARACTER_LENGTH\|CHARACTER_SET_CATALOG\|CHARACTER_SET_NAME\|CHARACTER_SET_SCHEMA\|CHAR_LENGTH\|CHECK\|CHECKED\|CHECKPOINT\|CLASS\|CLASS_ORIGIN\|CLOB\|CLOSE\|CLUSTER\|COALESCE\|COBOL\|COLLATE\|COLLATION\|COLLATION_CATALOG\|COLLATION_NAME\|COLLATION_SCHEMA\|COLLECT\|COLUMN\|COLUMN_NAME\|COMMAND_FUNCTION\|COMMAND_FUNCTION_CODE\|COMMENT\|COMMIT\|COMMITTED\|COMPLETION\|CONDITION\|CONDITION_NUMBER\|CONNECT\|CONNECTION\|CONNECTION_NAME\|CONSTRAINT\|CONSTRAINTS\|CONSTRAINT_CATALOG\|CONSTRAINT_NAME\|CONSTRAINT_SCHEMA\|CONSTRUCTOR\|CONTAINS\|CONTINUE\|CONVERSION\|CONVERT\|COPY\|CORR\|CORRESPONDING\|COUNT\|COVAR_POP\|COVAR_SAMP\|CREATE\|CREATEDB\|CREATEROLE\|CREATEUSER\|CROSS\|CSV\|CUBE\|CUME_DIST\|CURRENT\|CURRENT_DATE\|CURRENT_DEFAULT_TRANSFORM_GROUP\|CURRENT_PATH\|CURRENT_ROLE\|CURRENT_TIME\|CURRENT_TIMESTAMP\|CURRENT_TRANSFORM_GROUP_FOR_TYPE\|CURRENT_USER\|CURSOR\|CURSOR_NAME\|CYCLE\)\t/\1_\t/ig' |
    sed 's/^\(DATA\|DATABASE\|DATE\|DATETIME_INTERVAL_CODE\|DATETIME_INTERVAL_PRECISION\|DAY\|DEALLOCATE\|DEC\|DECIMAL\|DECLARE\|DEFAULT\|DEFAULTS\|DEFERRABLE\|DEFERRED\|DEFINED\|DEFINER\|DEGREE\|DELETE\|DELIMITER\|DELIMITERS\|DENSE_RANK\|DEPTH\|DEREF\|DERIVED\|DESC\|DESCRIBE\|DESCRIPTOR\|DESTROY\|DESTRUCTOR\|DETERMINISTIC\|DIAGNOSTICS\|DICTIONARY\|DISABLE\|DISCONNECT\|DISPATCH\|DISTINCT\|DO\|DOMAIN\|DOUBLE\|DROP\|DYNAMIC\|DYNAMIC_FUNCTION\|DYNAMIC_FUNCTION_CODE\)\t/\1_\t/ig' |
    sed 's/^\(EACH\|ELEMENT\|ELSE\|ENABLE\|ENCODING\|ENCRYPTED\|END\|END-EXEC\|EQUALS\|ESCAPE\|EVERY\|EXCEPT\|EXCEPTION\|EXCLUDE\|EXCLUDING\|EXCLUSIVE\|EXEC\|EXECUTE\|EXISTING\|EXISTS\|EXP\|EXPLAIN\|EXTERNAL\|EXTRACT\)\t/\1_\t/ig' |
    sed 's/^\(FALSE\|FETCH\|FILTER\|FINAL\|FIRST\|FLOAT\|FLOOR\|FOLLOWING\|FOR\|FORCE\|FOREIGN\|FORTRAN\|FORWARD\|FOUND\|FREE\|FREEZE\|FROM\|FULL\|FUNCTION\|FUSION\)\t/\1_\t/ig' |
    sed 's/^\(G\|GENERAL\|GENERATED\|GET\|GLOBAL\|GO\|GOTO\|GRANT\|GRANTED\|GREATEST\|GROUP\|GROUPING\)\t/\1_\t/ig' |
    sed 's/^\(HANDLER\|HAVING\|HEADER\|HIERARCHY\|HOLD\|HOST\|HOUR\)\t/\1_\t/ig' |
    sed 's/^\(IDENTITY\|IGNORE\|ILIKE\|IMMEDIATE\|IMMUTABLE\|IMPLEMENTATION\|IMPLICIT\|IN\|INCLUDING\|INCREMENT\|INDEX\|INDICATOR\|INFIX\|INHERIT\|INHERITS\|INITIALIZE\|INITIALLY\|INNER\|INOUT\|INPUT\|INSENSITIVE\|INSERT\|INSTANCE\|INSTANTIABLE\|INSTEAD\|INT\|INTEGER\|INTERSECT\|INTERSECTION\|INTERVAL\|INTO\|INVOKER\|IS\|ISNULL\|ISOLATION\|ITERATE\)\t/\1_\t/ig' |
    sed 's/^\(JOIN\)\t/\1_\t/ig' |
    sed 's/^\(K\|KEY\|KEY_MEMBER\|KEY_TYPE\)\t/\1_\t/ig' |
    sed 's/^\(LANCOMPILER\|LANGUAGE\|LARGE\|LAST\|LATERAL\|LEADING\|LEAST\|LEFT\|LENGTH\|LESS\|LEVEL\|LIKE\|LIMIT\|LISTEN\|LN\|LOAD\|LOCAL\|LOCALTIME\|LOCALTIMESTAMP\|LOCATION\|LOCATOR\|LOGIN\|LOCK\|LOWER\)\t/\1_\t/ig' |
    sed 's/^\(M\|MAP\|MATCH\|MATCHED\|MAX\|MAXVALUE\|MEMBER\|MERGE\|MESSAGE_LENGTH\|MESSAGE_OCTET_LENGTH\|MESSAGE_TEXT\|METHOD\|MIN\|MINUTE\|MINVALUE\|MOD\|MODE\|MODIFIES\|MODIFY\|MODULE\|MONTH\|MORE\|MOVE\|MULTISET\|MUMPS\)\t/\1_\t/ig' |
    sed 's/^\(NAME\|NAMES\|NATIONAL\|NATURAL\|NCHAR\|NCLOB\|NESTING\|NEW\|NEXT\|NO\|NOCREATEDB\|NOCREATEROLE\|NOCREATEUSER\|NOINHERIT\|NOLOGIN\|NONE\|NORMALIZE\|NORMALIZED\|NOSUPERUSER\|NOT\|NOTHING\|NOTIFY\|NOTNULL\|NOWAIT\|NULL\|NULLABLE\|NULLIF\|NULLS\|NUMBER\|NUMERIC\)\t/\1_\t/ig' |
    sed 's/^\(OBJECT\|OCTETS\|OCTET_LENGTH\|OF\|OFF\|OFFSET\|OIDS\|OLD\|ON\|ONLY\|OPEN\|OPERATION\|OPERATOR\|OPTION\|OPTIONS\|OR\|ORDER\|ORDERING\|ORDINALITY\|OTHERS\|OUT\|OUTER\|OUTPUT\|OVER\|OVERLAPS\|OVERLAY\|OVERRIDING\|OWNER\)\t/\1_\t/ig' |
    sed 's/^\(PAD\|PARAMETER\|PARAMETERS\|PARAMETER_MODE\|PARAMETER_NAME\|PARAMETER_ORDINAL_POSITION\|PARAMETER_SPECIFIC_CATALOG\|PARAMETER_SPECIFIC_NAME\|PARAMETER_SPECIFIC_SCHEMA\|PARTIAL\|PARTITION\|PASCAL\|PASSWORD\|PATH\|PERCENTILE_CONT\|PERCENTILE_DISC\|PERCENT_RANK\|PLACING\|PLI\|POSITION\|POSTFIX\|POWER\|PRECEDING\|PRECISION\|PREFIX\|PREORDER\|PREPARE\|PREPARED\|PRESERVE\|PRIMARY\|PRIOR\|PRIVILEGES\|PROCEDURAL\|PROCEDURE\|PUBLIC\)\t/\1_\t/ig' |
    sed 's/^\(QUOTE\)\t/\1_\t/ig' |
    sed 's/^\(RANGE\|RANK\|READ\|READS\|REAL\|RECHECK\|RECURSIVE\|REF\|REFERENCES\|REFERENCING\|REGR_AVGX\|REGR_AVGY\|REGR_COUNT\|REGR_INTERCEPT\|REGR_R2\|REGR_SLOPE\|REGR_SXX\|REGR_SXY\|REGR_SYY\|REINDEX\|RELATIVE\|RELEASE\|RENAME\|REPEATABLE\|REPLACE\|RESET\|RESTRICT\|RESULT\|RETURN\|RETURNED_CARDINALITY\|RETURNED_LENGTH\|RETURNED_OCTET_LENGTH\|RETURNED_SQLSTATE\|RETURNS\|REVOKE\|RIGHT\|ROLE\|ROLLBACK\|ROLLUP\|ROUTINE\|ROUTINE_CATALOG\|ROUTINE_NAME\|ROUTINE_SCHEMA\|ROW\|ROWS\|ROW_COUNT\|ROW_NUMBER\|RULE\)\t/\1_\t/ig' |
    sed 's/^\(SAVEPOINT\|SCALE\|SCHEMA\|SCHEMA_NAME\|SCOPE\|SCOPE_CATALOG\|SCOPE_NAME\|SCOPE_SCHEMA\|SCROLL\|SEARCH\|SECOND\|SECTION\|SECURITY\|SELECT\|SELF\|SENSITIVE\|SEQUENCE\|SERIALIZABLE\|SERVER_NAME\|SESSION\|SESSION_USER\|SET\|SETOF\|SETS\|SHARE\|SHOW\|SIMILAR\|SIMPLE\|SIZE\|SMALLINT\|SOME\|SOURCE\|SPACE\|SPECIFIC\|SPECIFICTYPE\|SPECIFIC_NAME\|SQL\|SQLCODE\|SQLERROR\|SQLEXCEPTION\|SQLSTATE\|SQLWARNING\|SQRT\|STABLE\|START\|STATE\|STATEMENT\|STATIC\|STATISTICS\|STDDEV_POP\|STDDEV_SAMP\|STDIN\|STDOUT\|STORAGE\|STRICT\|STRUCTURE\|STYLE\|SUBCLASS_ORIGIN\|SUBLIST\|SUBMULTISET\|SUBSTRING\|SUM\|SUPERUSER\|SYMMETRIC\|SYSID\|SYSTEM\|SYSTEM_USER\)\t/\1_\t/ig' |
    sed 's/^\(TABLE\|TABLESAMPLE\|TABLESPACE\|TABLE_NAME\|TEMP\|TEMPLATE\|TEMPORARY\|TERMINATE\|THAN\|THEN\|TIES\|TIME\|TIMESTAMP\|TIMEZONE_HOUR\|TIMEZONE_MINUTE\|TO\|TOAST\|TOP_LEVEL_COUNT\|TRAILING\|TRANSACTION\|TRANSACTIONS_COMMITTED\|TRANSACTIONS_ROLLED_BACK\|TRANSACTION_ACTIVE\|TRANSFORM\|TRANSFORMS\|TRANSLATE\|TRANSLATION\|TREAT\|TRIGGER\|TRIGGER_CATALOG\|TRIGGER_NAME\|TRIGGER_SCHEMA\|TRIM\|TRUE\|TRUNCATE\|TRUSTED\|TYPE\)\t/\1_\t/ig' |
    sed 's/^\(UESCAPE\|UNBOUNDED\|UNCOMMITTED\|UNDER\|UNENCRYPTED\|UNION\|UNIQUE\|UNKNOWN\|UNLISTEN\|UNNAMED\|UNNEST\|UNTIL\|UPDATE\|UPPER\|USAGE\|USER\|USER_DEFINED_TYPE_CATALOG\|USER_DEFINED_TYPE_CODE\|USER_DEFINED_TYPE_NAME\|USER_DEFINED_TYPE_SCHEMA\|USING\)\t/\1_\t/ig' |
    sed 's/^\(VACUUM\|VALID\|VALIDATOR\|VALUE\|VALUES\|VARCHAR\|VARIABLE\|VARYING\|VAR_POP\|VAR_SAMP\|VERBOSE\|VIEW\|VOLATILE\)\t/\1_\t/ig' |
    sed 's/^\(WHEN\|WHENEVER\|WHERE\|WIDTH_BUCKET\|WINDOW\|WITH\|WITHIN\|WITHOUT\|WORK\|WRITE\)\t/\1_\t/ig' |
    sed 's/^\(YEAR\)\t/\1_\t/ig'
}

init_pg_db
