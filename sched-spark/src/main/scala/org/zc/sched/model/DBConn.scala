package org.zc.sched.model

import java.util.Properties
import java.sql.ResultSet

import org.zc.sched.util.ConfigUtil

case class DBConn(id: Int, dbType: Int, connType: Int, hostname: String, port: Int,
  username: String, password: String, dbName: String, charset: String) {

  // 驱动名
  val JDBC_DRIVER_MYSQL = ConfigUtil.getString("jdbc.driver.mysql")
  val JDBC_DRIVER_HIVE = ConfigUtil.getString("jdbc.driver.hive")
  val JDBC_DRIVER_PHOENIX = ConfigUtil.getString("jdbc.driver.phoenix")

  def jdbcDriver = if (dbType > 0) {
    dbType match {
      case DBConn.DB_TYPE_MYSQL => JDBC_DRIVER_MYSQL
      case DBConn.DB_TYPE_HIVE => JDBC_DRIVER_HIVE
      case DBConn.DB_TYPE_PHOENIX => JDBC_DRIVER_PHOENIX
      case _ => throw new RuntimeException(s"Unsupported database type: ${dbType}")
    }
  } else { null }

  def jdbcUrl = if (dbType > 0) {
    dbType match {
      case DBConn.DB_TYPE_MYSQL => s"jdbc:mysql://${hostname}:${port}/${dbName}?useUnicode=true&characterEncoding=${charset}"
      case DBConn.DB_TYPE_HIVE =>
        if (connType == DBConn.CONN_TYPE_ZOOKEEPER) s"jdbc:hive2://${hostname}/;serviceDiscoveryMode=zooKeeper;zooKeeperNamespace=hiveserver2"
        else s"jdbc:hive2://${hostname}:${port}/${dbName}"
      case DBConn.DB_TYPE_PHOENIX => s"jdbc:phoenix:${hostname}"
      case _ => throw new RuntimeException(s"Unsupported database type: ${dbType}")
    }
  } else { null }

  def connProps = {
    val props = new Properties
    props.put("user", username)
    props.put("password", password)
    props
  }

}

object DBConn {

  // 数据库类型
  val DB_TYPE_MYSQL = 1
  val DB_TYPE_ORACLE = 2
  val DB_TYPE_MSSQLSERVER = 3
  val DB_TYPE_SYBASE = 4
  val DB_TYPE_POSTGRESQL = 5
  val DB_TYPE_DB2 = 6
  val DB_TYPE_HIVE = 7
  val DB_TYPE_DERBY = 8
  val DB_TYPE_FS = 9
  val DB_TYPE_HDFS = 10
  val DB_TYPE_SAIKU = 11
  val DB_TYPE_PHOENIX = 12

  // 数据库连接方式
  val CONN_TYPE_CLI = 0
  val CONN_TYPE_JDBC = 1
  val CONN_TYPE_ODBC = 2
  val CONN_TYPE_HTTP = 3
  val CONN_TYPE_ZOOKEEPER = 4

  def apply(id: Int, rs: ResultSet): DBConn = {
    DBConn(id, rs.getInt("type_id"), rs.getInt("conn_type"), rs.getString("hostname"), rs.getInt("port"),
      rs.getString("username"), rs.getString("password"), rs.getString("db_name"), rs.getString("charset"))
  }

}