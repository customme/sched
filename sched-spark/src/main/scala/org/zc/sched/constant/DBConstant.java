package org.zc.sched.constant;

public interface DBConstant {

	/**
	 * 创建表模式
	 */
	public static final String CREATE_MODE_SKIP = "skip"; // 跳过
	public static final String CREATE_MODE_AUTO = "auto"; // 自动创建
	public static final String CREATE_MODE_DROP = "drop"; // 先删除后创建

	/**
	 * 数据库类型
	 */
	public static final int DB_TYPE_MYSQL = 1;
	public static final int DB_TYPE_ORACLE = 2;
	public static final int DB_TYPE_MSSQLSERVER = 3;
	public static final int DB_TYPE_SYBASE = 4;
	public static final int DB_TYPE_POSTGRESQL = 5;
	public static final int DB_TYPE_DB2 = 6;
	public static final int DB_TYPE_HIVE = 7;
	public static final int DB_TYPE_DERBY = 8;
	public static final int DB_TYPE_FS = 9;
	public static final int DB_TYPE_HDFS = 10;
	public static final int DB_TYPE_SAIKU = 11;
	public static final int DB_TYPE_PHOENIX = 12;

	/**
	 * 数据库连接方式
	 */
	public static final int CONN_TYPE_CLI = 0;
	public static final int CONN_TYPE_JDBC = 1;
	public static final int CONN_TYPE_ODBC = 2;
	public static final int CONN_TYPE_HTTP = 3;
	public static final int CONN_TYPE_ZOOKEEPER = 4;

}
