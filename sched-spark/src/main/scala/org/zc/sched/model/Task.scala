package org.zc.sched.model

import java.sql.ResultSet

import org.apache.commons.lang3.StringUtils

import org.json4s._
import org.json4s.jackson.JsonMethods._
import com.fasterxml.jackson.core.JsonParser.Feature

import org.zc.sched.util.DateUtil

case class Task(taskId: Int, runTime: String, taskName: String, taskCycle: String, isFirst: Boolean,
  redoFlag: Boolean, runParams: Map[String, String]) {

  val taskNo = DateUtil.formatDate(Task.RUNTIME_FORMAT).toLong

  val taskExt: collection.mutable.Map[String, String] = collection.mutable.Map()

  val theTime = DateUtil.getDatetime(runTime, Task.RUNTIME_FORMAT)
  val prevTime = if (Task.TASK_CYCLE_HOUR.equalsIgnoreCase(taskCycle)) {
    DateUtil.nextHour(-1, theTime)
  } else DateUtil.nextDate(-1, theTime)

  val theDate = DateUtil.formatDate(theTime)
  val prevDate = DateUtil.formatDate(DateUtil.nextDate(-1, theTime))
  val statDate = prevDate.replaceAll("-", "").toInt
}

object Task {

  val RUNTIME_FORMAT = "yyyyMMddHHmmss"

  val TASK_CYCLE_DAY = "day"
  val TASK_CYCLE_WEEK = "week"
  val TASK_CYCLE_MONTH = "month"
  val TASK_CYCLE_HOUR = "hour"
  val TASK_CYCLE_INTERVAL = "interval"
  val TASK_CYCLE_INSTANT = "instant"
  val TASK_CYCLE_INCESSANT = "incessant"

  def apply(taskId: Int, runTime: String, rs: ResultSet): Task = {
    val runParams = rs.getString("run_params")
    val _runParams = if (StringUtils.isNotBlank(runParams)) {
      try {
        mapper.configure(Feature.ALLOW_UNQUOTED_FIELD_NAMES, true)
        parse(runParams).values.asInstanceOf[Map[String, String]]
      } catch {
        case _: Exception =>
          val array = runParams.split("\r\n").map { line =>
            val arr = line.split("=")
            (arr(0), arr(1))
          }
          if (array.size > 0) array.toMap else Map("runParams" -> runParams)
      }
    } else Map[String, String]()

    Task(taskId, runTime, rs.getString("name"), rs.getString("task_cycle"), rs.getBoolean("is_first"),
      rs.getBoolean("redo_flag"), _runParams)
  }
}