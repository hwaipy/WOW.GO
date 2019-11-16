package com.hwaipy.wow

import java.awt.event.{InputEvent, KeyEvent}
import java.awt.{Rectangle, Robot, Toolkit}
import java.io.{ByteArrayOutputStream, PrintStream}
import java.util.Properties
import java.util.concurrent.Executors
import scala.io.Source
import scala.util.Random
import org.python.core.PyException
import org.python.util.PythonInterpreter
import scalafx.beans.property.{BooleanProperty, StringProperty}
import scala.concurrent.{ExecutionContext, Future}

object WowGo {
  private val robot = new Robot()
  private val random = new Random()
  val screenSize = Toolkit.getDefaultToolkit.getScreenSize

  //QUEUE, ERROR, LOGIN, BEGIN, NORMAL
  def checkUIStatus() = {
    LinkGo.status(robot.createScreenCapture(new Rectangle(0, 0, screenSize.width, screenSize.height)))
  }

  def delay(from: Int, to: Int = -1) = if (to > from) Thread.sleep(random.nextInt(to - from) + from) else Thread.sleep(from)

  def actionMouseClick(x: Double, y: Double, isLeft: Boolean = true) = {
    val button = if (isLeft) InputEvent.BUTTON1_DOWN_MASK else InputEvent.BUTTON3_DOWN_MASK
    robot.mouseMove(x.toInt, y.toInt)
    delay(50, 100)
    robot.mousePress(button)
    delay(50, 100)
    robot.mouseRelease(button)
    delay(50, 100)
  }

  def actionKeyClick(keyCode: Int): Unit = {
    robot.keyPress(keyCode)
    delay(50, 100)
    robot.keyRelease(keyCode)
    delay(50, 100)
  }

  def actionKeyClick(keyString: String, functionKey: String): Unit = {
    val keyCode = functionKey.toUpperCase() match {
      case "SHIFT" => KeyEvent.VK_SHIFT
      case "CTRL" => KeyEvent.VK_CONTROL
      case "ALT" => KeyEvent.VK_ALT
      case _ => -1
    }
    if (keyCode != -1) {
      robot.keyPress(keyCode)
      delay(50, 100)
    }
    keyString.foreach(c => actionKeyClick(c))
    if (keyCode != -1) {
      robot.keyRelease(keyCode)
      delay(50, 100)
    }
  }

  val jythonInitProperties = new Properties()
  jythonInitProperties.setProperty("python.import.site", "false")
  PythonInterpreter.initialize(System.getProperties, jythonInitProperties, new Array[String](0))
  val interpreter = new PythonInterpreter()
  val runningProperty = new BooleanProperty()
  val battleNetPath = new StringProperty("")

  def run(cmd: String) = {
    runningProperty set true
    JythonBridge.UIStatus = checkUIStatus()
    JythonBridge.reactionDelayTime = -1
    try {
      val pre =
        """
          |from com.hwaipy.wow.JythonBridge import *
          |
          |def lockOn():
          |  uistatus = UIStatus()
          |  if uistatus == 'NORMAL':
          |    UIActionNormal()
          |  elif uistatus == 'BEGIN':
          |    UIActionBegin()
          |  elif uistatus == 'LOGIN':
          |    UIActionLogin()
          |  elif uistatus == 'ERROR':
          |    UIActionError()
          |  elif uistatus == 'QUEUE':
          |    UIActionQueue()
          |  else:
          |    raise RuntimeError("Wrong UI Status.")
          |
        """.stripMargin
      val logi = Source.fromFile("magic.py").getLines().toList.mkString(System.lineSeparator())
      val lockOn =
        """
          |lockOn()
        """.stripMargin
      val actionReopen =
        """
          |actionReopen()
        """.stripMargin
      val post = cmd match {
        case "LOCK_ON" => lockOn
        case "ACTION_REOPEN" => actionReopen
        case _ => throw new RuntimeException(s"Unknown commond: ${cmd}")
      }
      val code = List(pre, logi, post).mkString(System.lineSeparator())
      interpreter.exec(code)
    } catch {
      case e: PyException => {
        val out = new ByteArrayOutputStream()
        e.printStackTrace(new PrintStream(out))
        out.close()
        val errorMsg = new String(out.toByteArray)
        println(errorMsg)
      }
      case e: Throwable => e.printStackTrace()
    }
    runningProperty set false
    JythonBridge.reactionDelayTime
  }

  private val executor = Executors.newSingleThreadExecutor()
  private val executionContext = ExecutionContext.fromExecutorService(executor)

  def runLater(cmd: String, end: (Double) => Unit = (a) => {}) = {
    runningProperty set true
    Future[Unit] {
      val reactionTime = run(cmd)
      runningProperty set false
      end(reactionTime)
    }(executionContext)
  }

  def exit() = {
    executor.shutdown()
  }
}

object JythonBridge {
  var UIStatus = "LOGIN"
  var reactionDelayTime = -1.0

  def leftButtonClick(x: Float, y: Float) = WowGo.actionMouseClick(x * WowGo.screenSize.width, y * WowGo.screenSize.height, true)

  def rightButtonClick(x: Float, y: Float) = WowGo.actionMouseClick(x, y, false)

  def keyClick(keyString: String, functionKey: String) = WowGo.actionKeyClick(keyString.toUpperCase(), functionKey)

  def keyClick(keyString: String) = WowGo.actionKeyClick(keyString.toUpperCase(), "")

  def keyClickESC() = WowGo.actionKeyClick(KeyEvent.VK_ESCAPE)

  def delay(time: Float) = Thread.sleep((time * 1000).toLong)

  def reactionDelay(time: Float) = reactionDelayTime = time

  def openBattleNet() = Runtime.getRuntime.exec("\"" + WowGo.battleNetPath.get + "\"")

  def debugSetUIStatus(status: String) = UIStatus = status

  Thread.setDefaultUncaughtExceptionHandler((t, e) => e.printStackTrace())
}
