package org.zc.sched.util

import java.sql.DriverManager
import java.sql.Connection
import java.sql.Statement
import java.sql.ResultSet

import org.zc.sched.model.DBConn

object JdbcUtil {

  /**
   * 执行sql查询返回单列单条记录
   */
  def executeQuery(db: DBConn, sql: String): Object = {
    Class.forName(db.jdbcDriver)
    val conn = DriverManager.getConnection(db.jdbcUrl, db.username, db.password)

    val rs = conn.createStatement.executeQuery(sql)
    val obj: Object = if (rs.next()) {
      rs.getObject(1)
    } else null

    closeAll(rs, null, conn)

    obj
  }

  /**
   * 执行sql更新
   */
  def executeUpdate(db: DBConn, sql: String): Int = {
    Class.forName(db.jdbcDriver)
    val conn = DriverManager.getConnection(db.jdbcUrl, db.username, db.password)

    val count = conn.createStatement().executeUpdate(sql)

    closeConn(conn)

    count
  }

  /**
   * 执行批量sql更新
   */
  def executeBatch(db: DBConn, sqls: Array[String]) {
    Class.forName(db.jdbcDriver)
    val conn = DriverManager.getConnection(db.jdbcUrl, db.username, db.password)
    val stmt = conn.createStatement

    conn.setAutoCommit(false)
    for (sql <- sqls) {
      stmt.addBatch(sql)
    }
    stmt.executeBatch
    conn.commit

    closeAll(null, stmt, conn)
  }

  /**
   * 关闭连接
   */
  def closeConn(conn: Connection) {
    closeAll(null, null, conn)
  }

  /**
   * 关闭所有连接
   */
  def closeAll(rs: ResultSet, stmt: Statement, conn: Connection) {
    if (rs != null) {
      try {
        rs.close
      } catch {
        case e: Exception => e.printStackTrace
      }
    }

    if (stmt != null) {
      try {
        stmt.close
      } catch {
        case e: Exception => e.printStackTrace
      }
    }

    if (conn != null) {
      try {
        conn.close
      } catch {
        case e: Exception => e.printStackTrace
      }
    }

  }

}