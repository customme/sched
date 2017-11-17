package org.zc.sched.util;

import java.sql.DriverManager;
import java.sql.Connection;
import java.sql.Statement;
import java.sql.ResultSet;
import java.sql.SQLException;

public class DBUtil {

	private static final String driver = ConfigUtil.getString("jdbc.driver.sched");
	private static final String url = ConfigUtil.getString("jdbc.url.sched");
	private static final String user = ConfigUtil.getString("jdbc.user.sched");
	private static final String password = ConfigUtil.getString("jdbc.password.sched");

	static {
		try {
			Class.forName(driver);
		} catch (ClassNotFoundException e) {
			e.printStackTrace();
		}
	}

	public static Connection getConn() throws SQLException {
		return DriverManager.getConnection(url, user, password);
	}

	public static void closeCon(Connection con) {
		closeAll(null, null, con);
	}

	public static void closeAll(ResultSet rs, Statement stmt, Connection con) {
		if (rs != null) {
			try {
				rs.close();
			} catch (SQLException e) {
				e.printStackTrace();
			} finally {
				rs = null;
			}
		}

		if (stmt != null) {
			try {
				stmt.close();
			} catch (SQLException e) {
				e.printStackTrace();
			} finally {
				stmt = null;
			}
		}

		if (con != null) {
			try {
				con.close();
			} catch (SQLException e) {
				e.printStackTrace();
			} finally {
				con = null;
			}
		}
	}

}