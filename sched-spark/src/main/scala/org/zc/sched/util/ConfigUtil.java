package org.zc.sched.util;

import java.io.File;

import org.apache.commons.configuration.ConfigurationException;
import org.apache.commons.configuration.PropertiesConfiguration;

public class ConfigUtil {

	public static final String LINUX_PATH = "/etc/sched/";
	public static final String WINDOWS_PATH = "../etc/";
	public static final String CONFIG_FILE = "config.properties";

	private static String CONFIG_FILE_PATH = "./" + CONFIG_FILE;

	private static PropertiesConfiguration config = null;

	static {
		if (existFile(CONFIG_FILE_PATH)) {
		} else if (existFile(LINUX_PATH + CONFIG_FILE)) {
			CONFIG_FILE_PATH = LINUX_PATH + CONFIG_FILE;
		} else if (existFile(WINDOWS_PATH + CONFIG_FILE)) {
			CONFIG_FILE_PATH = WINDOWS_PATH + CONFIG_FILE;
		}
		try {
			load();
		} catch (ConfigurationException e) {
			e.printStackTrace();
		}
	}

	private static boolean existFile(String fileName) {
		return new File(fileName).exists();
	}

	private static void load() throws ConfigurationException {
		config = new PropertiesConfiguration();
		config.setEncoding("UTF-8");
		config.load(CONFIG_FILE_PATH);
	}

	public static int getInt(String key) {
		int reInt = 0;
		try {
			reInt = config.getInt(key);
		} catch (Exception e) {
			e.fillInStackTrace();
		}
		return reInt;
	}

	public static Long getLong(String key) {
		Long reLong = 0l;
		try {
			reLong = config.getLong(key);
		} catch (Exception e) {
			e.fillInStackTrace();
		}
		return reLong;
	}

	public static double getDouble(String key) {
		double reDouble = 0;
		try {
			reDouble = config.getDouble(key);
		} catch (Exception e) {
			e.fillInStackTrace();
		}
		return reDouble;
	}

	public static String getString(String key) {
		String str = "";
		try {
			str = config.getString(key);
		} catch (Exception e) {
			e.fillInStackTrace();
		}
		return str;
	}

	public static Boolean getBoolean(String key) {
		Boolean flag = false;
		try {
			flag = config.getBoolean(key);
		} catch (Exception e) {
			e.fillInStackTrace();
		}
		return flag;
	}

	public synchronized static void save(String key, Object o) {
		config.setProperty(key, o);
		try {
			config.save(CONFIG_FILE_PATH);
			load();
		} catch (ConfigurationException e) {
			e.printStackTrace();
		}
	}

	public static void main(String[] args) {
		System.out.println(getString("jdbc.url.sched"));
		System.out.println(System.getProperty("os.name"));
	}

}