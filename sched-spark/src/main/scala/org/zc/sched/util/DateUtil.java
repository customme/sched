package org.zc.sched.util;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.List;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.sql.Time;
import java.util.Map;
import java.util.HashMap;

public class DateUtil {

	public static final int MSEC_PRE_SECOND = 1000;
	public static final int MSEC_PRE_MINUTE = MSEC_PRE_SECOND * 60;
	public static final int MSEC_PRE_HOUR = MSEC_PRE_MINUTE * 60;
	public static final int MSEC_PRE_DAY = MSEC_PRE_HOUR * 24;

	public static final String FORMAT_DATETIME = "yyyy-MM-dd HH:mm:ss";
	public static final String FORMAT_DATETIME_ZH = "yyyy年MM月dd日 HH时mm分ss秒";
	public static final String FORMAT_DATE = "yyyy-MM-dd";
	public static final String FORMAT_DATE_ZH = "yyyy年MM月dd日";
	public static final String FORMAT_TIME = "HH:mm:ss";
	public static final String FORMAT_TIME_ZH = "HH时mm分ss秒";
	public static final String FORMAT_DAY = "E";

	public static Date getDatetime(String datestr) throws ParseException {
		return getDatetime(datestr, FORMAT_DATETIME);
	}

	/**
	 * 把日期字符串包装成java.util.Date
	 * 
	 * @param datestr
	 * @param format
	 * @return
	 * @throws ParseException
	 */
	public static Date getDatetime(String datestr, String format) throws ParseException {
		SimpleDateFormat formatter = new SimpleDateFormat(format);
		return formatter.parse(datestr);
	}

	/**
	 * 去掉时分秒
	 * 
	 * @param date
	 * @return
	 */
	public static Date trimTime(Date date) {
		Calendar calendar = Calendar.getInstance();
		calendar.setTime(date);
		calendar.set(Calendar.HOUR_OF_DAY, 0);
		calendar.set(Calendar.MINUTE, 0);
		calendar.set(Calendar.SECOND, 0);
		calendar.set(Calendar.MILLISECOND, 0);

		return calendar.getTime();
	}

	/**
	 * 去掉分秒
	 * 
	 * @param date
	 * @return
	 */
	public static Date trimMS(Date date) {
		Calendar calendar = Calendar.getInstance();
		calendar.setTime(date);
		calendar.set(Calendar.MINUTE, 0);
		calendar.set(Calendar.SECOND, 0);
		calendar.set(Calendar.MILLISECOND, 0);

		return calendar.getTime();
	}

	public static java.sql.Date getDate(String datestr) {
		return java.sql.Date.valueOf(datestr);
	}

	/**
	 * 把日期字符串包装成java.sql.Date
	 * 
	 * @param datestr
	 * @param format
	 * @return
	 * @throws ParseException
	 */
	public static java.sql.Date getDate(String datestr, String format) throws ParseException {
		return new java.sql.Date(getDatetime(datestr, format).getTime());
	}

	public static Time getTime(String datestr) throws ParseException {
		return getTime(datestr, FORMAT_TIME);
	}

	/**
	 * 把日期字符串包装成java.sql.Time
	 * 
	 * @param datestr
	 * @param format
	 * @return
	 */
	public static Time getTime(String datestr, String format) throws ParseException {
		return new Time(getDatetime(datestr, format).getTime());
	}

	public static String formatDatetime(Date... date) {
		return formatDate(FORMAT_DATETIME, date);
	}

	public static String formatDate(Date... date) {
		return formatDate(FORMAT_DATE, date);
	}

	public static String formatTime(Date... date) {
		return formatDate(FORMAT_TIME, date);
	}

	public static String formatDay(Date... date) {
		return formatDate(FORMAT_DAY, date);
	}

	public static String formatDate(String datestr, String srcformat, String descformat) throws ParseException {
		return formatDate(descformat, getDatetime(datestr, srcformat));
	}

	/**
	 * 格式化日期时间
	 * 
	 * @param format
	 * @param date
	 * @return
	 */
	public static String formatDate(String format, Date... date) {
		SimpleDateFormat formatter = new SimpleDateFormat(format);
		return formatter.format(date.length == 1 ? date[0] : new Date());
	}

	public static Date nextDate(Date... date) {
		return nextDate(1, date);
	}

	/**
	 * 计算某个日期相隔几天后的日期
	 * 
	 * @param interval
	 * @param date
	 * @return
	 */
	public static Date nextDate(int interval, Date... date) {
		Calendar calendar = Calendar.getInstance();
		calendar.setTime(date.length == 1 ? date[0] : new Date());
		calendar.add(Calendar.DATE, interval);
		return new Date(calendar.getTimeInMillis());
	}

	public static Date nextHour(Date... date) {
		return nextHour(1, date);
	}

	/**
	 * 计算某个时间相隔几个小时后的时间
	 * 
	 * @param interval
	 * @param date
	 * @return
	 */
	public static Date nextHour(int interval, Date... date) {
		Calendar calendar = Calendar.getInstance();
		calendar.setTime(date.length == 1 ? date[0] : new Date());
		calendar.add(Calendar.HOUR_OF_DAY, interval);
		return new Date(calendar.getTimeInMillis());
	}

	/**
	 * 计算某个时间相隔几个月后的时间
	 * 
	 * @param interval
	 * @param date
	 * @return
	 */
	public static Date nextMonth(int interval, Date... date) {
		Calendar calendar = Calendar.getInstance();
		calendar.setTime(date.length == 1 ? date[0] : new Date());
		calendar.add(Calendar.MONTH, interval);
		return new Date(calendar.getTimeInMillis());
	}

	public static long intervalDays(String datestr, boolean... strict) throws ParseException {
		return intervalDays(strict.length == 1 ? strict[0] : false, getDatetime(datestr));
	}

	public static long intervalDays(String datestr, String refdatestr, boolean... strict) throws ParseException {
		return intervalDays(datestr, refdatestr, FORMAT_DATETIME, strict);
	}

	public static long intervalDays(String datestr, String refdatestr, String format, boolean... strict) throws ParseException {
		return intervalDays(strict.length == 1 ? strict[0] : false, getDatetime(datestr, format), getDatetime(refdatestr, format));
	}

	public static long intervalDays(Date... date) {
		return intervalDays(false, date);
	}

	/**
	 * 计算某个日期和参考日期之间相隔的天数
	 * 
	 * @param strict
	 *            是否严格区分时分秒
	 * @param date
	 * @return
	 */
	public static long intervalDays(boolean strict, Date... date) {
		long datetime = date[0].getTime();
		long reftime = date.length == 2 ? date[1].getTime() : new Date().getTime();
		if (strict) {
			Calendar calendar = Calendar.getInstance();
			calendar.setTime(date[0]);
			Map<Integer, Integer> values = new HashMap<Integer, Integer>();
			values.put(Calendar.HOUR_OF_DAY, 0);
			values.put(Calendar.MINUTE, 0);
			values.put(Calendar.SECOND, 0);
			values.put(Calendar.MILLISECOND, 0);
			calendar = getCalendar(values, calendar);
			datetime = calendar.getTimeInMillis();
			calendar.setTime(date.length == 2 ? date[1] : new Date());
			calendar = getCalendar(values, calendar);
			reftime = calendar.getTimeInMillis();
		}
		return (reftime - datetime) / MSEC_PRE_DAY;
	}

	public static Date firstDate(String datestr) throws ParseException {
		return firstDate(datestr, FORMAT_DATETIME);
	}

	public static Date firstDate(String datestr, String format) throws ParseException {
		return firstDate(getDatetime(datestr, format));
	}

	/**
	 * 获取某个月的第一天
	 * 
	 * @param date
	 * @return
	 */
	public static Date firstDate(Date... date) {
		Calendar calendar = Calendar.getInstance();
		calendar.setTime(date.length == 1 ? date[0] : new Date());
		calendar.set(Calendar.DAY_OF_MONTH, calendar.getActualMinimum(Calendar.DAY_OF_MONTH));
		return new Date(calendar.getTimeInMillis());
	}

	public static Date lastDate(String datestr) throws ParseException {
		return lastDate(datestr, FORMAT_DATETIME);
	}

	public static Date lastDate(String datestr, String format) throws ParseException {
		return lastDate(getDatetime(datestr, format));
	}

	/**
	 * 获取某个月的最后一天
	 * 
	 * @param date
	 * @return
	 */
	public static Date lastDate(Date... date) {
		Calendar calendar = Calendar.getInstance();
		calendar.setTime(date.length == 1 ? date[0] : new Date());
		calendar.set(Calendar.DAY_OF_MONTH, calendar.getActualMaximum(Calendar.DAY_OF_MONTH));
		return new Date(calendar.getTimeInMillis());
	}

	public static int getDays(String datestr) throws ParseException {
		return getDays(datestr, FORMAT_DATETIME);
	}

	public static int getDays(String datestr, String format) throws ParseException {
		return getDays(getDatetime(datestr, format));
	}

	/**
	 * 获取某个月的天数
	 * 
	 * @param date
	 * @return
	 */
	public static int getDays(Date... date) {
		Calendar calendar = Calendar.getInstance();
		calendar.setTime(date.length == 1 ? date[0] : new Date());
		return calendar.getActualMaximum(Calendar.DAY_OF_MONTH);
	}

	/**
	 * 设置java.util.Calendar
	 * 
	 * @param values
	 * @param calendar
	 * @return
	 */
	public static Calendar getCalendar(Map<Integer, Integer> values, Calendar... calendar) {
		Calendar cal = calendar.length == 1 ? calendar[0] : Calendar.getInstance();
		for (Integer key : values.keySet()) {
			cal.set(key, values.get(key));
		}
		return cal;
	}

	/**
	 * 剩余天时分秒
	 * 
	 * @param date
	 * @return
	 */
	public static Map<Integer, Integer> leftTime(Date... date) {
		Date datetime = date[0];
		Date reftime = date.length == 2 ? date[1] : new Date();
		long msec = reftime.getTime() - datetime.getTime();
		long days = msec / MSEC_PRE_DAY;
		long hours = msec % MSEC_PRE_DAY / MSEC_PRE_HOUR;
		long minutes = msec % MSEC_PRE_DAY % MSEC_PRE_HOUR / MSEC_PRE_MINUTE;
		long seconds = msec % MSEC_PRE_DAY % MSEC_PRE_HOUR % MSEC_PRE_MINUTE / MSEC_PRE_SECOND;
		Map<Integer, Integer> values = new HashMap<Integer, Integer>();
		values.put(Calendar.DAY_OF_MONTH, (int) days);
		values.put(Calendar.HOUR_OF_DAY, (int) hours);
		values.put(Calendar.MINUTE, (int) minutes);
		values.put(Calendar.SECOND, (int) seconds);
		return values;
	}

	/**
	 * 生成指定日间隔的日期范围
	 * 
	 * @param interval
	 * @param date
	 * @return
	 */
	public static List<String> rangeDate(int interval, Date... dates) {
		Date startDate = dates[0];
		Date endDate = dates.length == 2 ? dates[1] : trimTime(new Date());

		List<String> list = new ArrayList<String>();

		Date nextDate = nextDate(interval, trimTime(startDate));
		while (nextDate.before(endDate)) {
			list.add(formatDatetime(startDate) + "," + formatDatetime(nextDate));
			startDate = nextDate;
			nextDate = nextDate(interval, nextDate);
		}
		list.add(formatDatetime(startDate) + "," + formatDatetime(endDate));

		return list;
	}

	/**
	 * 生成指定小时间隔的日期范围
	 * 
	 * @param interval
	 * @param date
	 * @return
	 */
	public static List<String> rangeHour(int interval, Date... dates) {
		Date startDate = dates[0];
		Date endDate = dates.length == 2 ? dates[1] : trimMS(new Date());

		List<String> list = new ArrayList<String>();

		Date nextDate = nextHour(interval, trimMS(startDate));
		while (nextDate.before(endDate)) {
			list.add(formatDatetime(startDate) + "," + formatDatetime(nextDate));
			startDate = nextDate;
			nextDate = nextHour(interval, nextDate);
		}
		list.add(formatDatetime(startDate) + "," + formatDatetime(endDate));

		return list;
	}

	/**
	 * 生成日期
	 * 
	 * @param dates
	 * @return
	 */
	public static List<Date> genDate(Date... dates) {
		Date startDate = trimTime(dates[0]);
		Date endDate = trimTime(dates.length == 2 ? dates[1] : new Date());

		List<Date> list = new ArrayList<Date>();
		list.add(startDate);

		Date nextDate = nextDate(1, startDate);
		while (nextDate.before(endDate)) {
			list.add(nextDate);
			nextDate = nextDate(1, nextDate);
		}
		list.add(endDate);

		return list;
	}

	public static void main(String[] args) throws Exception {
		List<String> list = rangeDate(1, getDatetime("2017-06-28 10:01:00"));
		for (String str : list) {
			String[] arr = str.split(",");
			System.out.println(arr[0] + "\t" + arr[1]);
		}

		List<Date> dates = genDate(getDatetime("2017-06-28 10:01:00"));
		for (Date date : dates) {
			System.out.println(formatDatetime(date));
		}
	}

}
