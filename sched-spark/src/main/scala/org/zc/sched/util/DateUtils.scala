package org.zc.sched.util

import java.util.Calendar
import java.util.Date

import scala.collection.mutable.ArrayBuffer

object DateUtils {

  /**
   * 生成指定日间隔的日期范围
   *
   * @param interval
   * @param dates
   * @return
   */
  def rangeDate(interval: Int = 1, startDate: Date, endDate: Date = DateUtil.trimTime(new Date())) = {
    val list = ArrayBuffer[(Date, Date)]()

    var nextDate = DateUtil.nextDate(interval, DateUtil.trimTime(startDate))
    var tmpDate = startDate
    while (nextDate.before(endDate)) {
      list += ((tmpDate, nextDate))
      tmpDate = nextDate
      nextDate = DateUtil.nextDate(interval, nextDate)
    }
    list += ((tmpDate, endDate))

    list.toArray
  }

  /**
   * 生成指定小时间隔的日期范围
   *
   * @param interval
   * @param dates
   * @return
   */
  def rangeHour(interval: Int = 1, startDate: Date, endDate: Date = DateUtil.trimMS(new Date())) = {
    val list = ArrayBuffer[(Date, Date)]()

    var nextDate = DateUtil.nextHour(interval, DateUtil.trimMS(startDate));
    var tmpDate = startDate
    while (nextDate.before(endDate)) {
      list += ((startDate, nextDate))
      tmpDate = nextDate
      nextDate = DateUtil.nextHour(interval, nextDate)
    }
    list += ((tmpDate, endDate))

    list.toArray
  }

  /**
   * 生成日期
   *
   * @param dates
   * @return
   */
  def genDate(dates: Date*) = {
    val startDate = DateUtil.trimTime(dates(0))
    val endDate = DateUtil.trimTime(if (dates.length == 2) dates(1) else new Date())

    val list = ArrayBuffer[Date]()
    list += startDate

    var nextDate = DateUtil.nextDate(1, startDate)
    while (nextDate.before(endDate)) {
      list += nextDate
      nextDate = DateUtil.nextDate(1, nextDate)
    }
    list += endDate

    list.toArray
  }

  def main(args: Array[String]): Unit = {
    var dates = rangeDate(10, DateUtil.getDate("2017-06-01"))
    dates.foreach(x => println(DateUtil.formatDatetime(x._1) + "\t" + DateUtil.formatDatetime(x._2)))

    dates = rangeHour(10, DateUtil.getDatetime("2017-07-01 01:30:30"))
    dates.foreach(x => println(DateUtil.formatDatetime(x._1) + "\t" + DateUtil.formatDatetime(x._2)))

    genDate(java.sql.Date.valueOf("2017-06-27")).foreach(x => println(DateUtil.formatDatetime(x)))
  }

}