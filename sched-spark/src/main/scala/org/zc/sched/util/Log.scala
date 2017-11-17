package org.zc.sched.util

import org.slf4j.LoggerFactory
import org.slf4j.Logger

trait Log {

  protected val log: Logger = LoggerFactory.getLogger(getClass().getName)

}