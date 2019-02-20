package org.zc.sched.plugins.spark

import java.sql.Connection
import java.sql.PreparedStatement
import java.sql.Statement
import java.sql.ResultSet
import java.sql.Timestamp

import scala.collection.JavaConversions.propertiesAsScalaMap

import org.apache.spark.SparkConf
import org.apache.spark.sql.SparkSession

import org.zc.sched.model.Task
import org.zc.sched.model.DBConn
import org.zc.sched.util.DBUtil
import org.zc.sched.util.ConfigUtil
import org.zc.sched.util.DateUtil
import org.zc.sched.util.Log
import org.zc.sched.constant.TaskConstant

abstract class TaskExecutor(task: Task) extends Serializable with Log {

  val sparkParallelism = ConfigUtil.getInt("spark.parallelism")
  val parallelism = task.taskExt.getOrElse("parallelism", sparkParallelism).toString.toInt

  val executorClasspath = task.taskExt.getOrElse(ConfigUtil.getString("spark.executor.classpath"), "")

  val appName = s"${task.taskName} - ${task.shortTime}"

  val sparkConf = new SparkConf().setAppName(appName).setExecutorEnv("SPARK_CLASSPATH", executorClasspath)

  lazy val spark = SparkSession.builder.config(sparkConf).getOrCreate()

  /**
   * 执行任务
   */
  def execute

  def run {
    execute

    if (!TaskConstant.TASK_CYCLE_INCESSANT.equals(task.taskCycle)) {
      log.debug("stop SparkContext")
      spark.stop()
    }
  }

  /**
   * 获取数据库连接信息
   */
  def getDbConn(id: Int): Option[DBConn] = {
    val conn = DBUtil.getConn
    val sql = s"SELECT type_id, conn_type, hostname, port, username, password, db_name, charset FROM t_db_conn WHERE id = ${id}"
    val stmt: Statement = conn.createStatement()
    val rs: ResultSet = stmt.executeQuery(sql)
    val db = if (rs.next()) {
      Some(DBConn(id, rs))
    } else None

    DBUtil.closeAll(rs, stmt, conn)

    db
  }

  /**
   * 记录数据库日志
   */
  def logTask(level: Int, content: String) {
    val conn = DBUtil.getConn
    val sql = "INSERT INTO t_task_log (task_id, run_time, seq_no, level, content, log_time) VALUES (?, ?, ?, ?, ?, ?)"
    val ps: PreparedStatement = conn.prepareStatement(sql)

    ps.setInt(1, task.taskId)
    ps.setTimestamp(2, new Timestamp(DateUtil.getDatetime(task.runTime, TaskConstant.RUNTIME_FORMAT).getTime))
    ps.setLong(3, task.taskNo)
    ps.setInt(4, level)
    ps.setString(5, content)
    ps.setTimestamp(6, new Timestamp(System.currentTimeMillis()))
    ps.executeUpdate()

    DBUtil.closeAll(null, ps, conn)
  }

}

object TaskExecutor extends Log {

  private var conn: Connection = null
  private var ps: PreparedStatement = null
  private var rs: ResultSet = null

  def main(args: Array[String]): Unit = {
    if (args.length < 3) {
      log.error("invalid arguments")
      System.exit(1)
    }
    log.info(args.mkString("argument list: { ", ", ", " }"))

    // 命令行参数
    val taskId = args(0).toInt
    val runTime = args(1)
    val appClass = args(2)

    // 获取数据库连接
    log.debug("get database connection")
    conn = DBUtil.getConn

    // 获取任务
    log.debug("get task")
    val task = getTask(taskId, runTime)
    if (task.isDefined) {
      // 获取任务扩展属性
      task.get.taskExt.++=(getTaskExt(task.get))
      log.info(s"got task: ${task.get.toString}")
    } else {
      log.error(s"can not find valid task by (taskId: ${taskId}, runTime: ${runTime})")
      System.exit(1)
    }

    // 关闭数据库连接
    log.debug("close database connection")
    DBUtil.closeAll(rs, ps, conn)

    // 启动任务
    log.debug("start task")
    Class.forName(appClass).getConstructors.head.newInstance(task.get).asInstanceOf[TaskExecutor].run
  }

  /**
   * 获取任务
   */
  def getTask(taskId: Int, runTime: String) = {
    val sql = "SELECT a.name, a.task_cycle, IF(b.run_time = a.first_time, 1, 0) is_first, b.redo_flag, b.run_params" +
      " FROM t_task a INNER JOIN t_task_pool b" +
      " ON a.id = b.task_id AND a.id = ? AND b.run_time = ?"
    ps = conn.prepareStatement(sql)
    ps.setInt(1, taskId)
    ps.setTimestamp(2, new Timestamp(DateUtil.getDatetime(runTime, TaskConstant.RUNTIME_FORMAT).getTime))

    rs = ps.executeQuery()
    if (rs.next()) {
      Some(Task(taskId, runTime, rs))
    } else {
      None
    }
  }

  /**
   * 获取任务扩展属性
   */
  def getTaskExt(task: Task) = {
    val taskExt: collection.mutable.Map[String, String] = collection.mutable.Map()

    val sql = "SELECT prop_name, prop_value FROM t_task_ext WHERE task_id = ?"
    ps = conn.prepareStatement(sql)
    ps.setInt(1, task.taskId)

    rs = ps.executeQuery()
    while (rs.next()) {
      taskExt(rs.getString(1)) = rs.getString(2)
    }

    taskExt
  }

}