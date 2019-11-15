package com.hwaipy.wow

import java.awt.event.{InputEvent, KeyEvent}
import java.awt.{Rectangle, Robot, Toolkit}
import java.io.{ByteArrayOutputStream, PrintStream}
import java.util.Properties

import scala.io.Source
import scala.util.Random
import org.python.core.PyException
import org.python.util.PythonInterpreter

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

  def actionKeyClick(keyString: String): Unit = {
    println(keyString)
    keyString.foreach(c => actionKeyClick(c))
  }

  val jythonInitProperties = new Properties()
  jythonInitProperties.setProperty("python.import.site", "false")
  PythonInterpreter.initialize(System.getProperties, jythonInitProperties, new Array[String](0))
  val interpreter = new PythonInterpreter()

  def run() = {
    JythonBridge.UIStatus = "LOGIN"
    try {
      val pre =
        """
          |from com.hwaipy.wow.JythonBridge import *
        """.stripMargin
      val logi = Source.fromFile("magic.py").getLines().toList.mkString(System.lineSeparator())
      val post =
        """
          |def main():
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
          |main()
          |
        """.stripMargin
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
  }
}

object JythonBridge {
  var UIStatus = "LOGIN"

  def leftButtonClick(x: Float, y: Float) = WowGo.actionMouseClick(x * WowGo.screenSize.width, y * WowGo.screenSize.height, true)

  def rightButtonClick(x: Float, y: Float) = WowGo.actionMouseClick(x, y, false)

  def keyClick(keyString: String) = WowGo.actionKeyClick(keyString.toUpperCase())

  def keyClickESC() = WowGo.actionKeyClick(KeyEvent.VK_ESCAPE)

  def delay(time: Float) = Thread.sleep((time * 1000).toLong)

  def openBattleNet() = Runtime.getRuntime.exec("open '/Users/hwaipy/Library/Application Support/Battle.net/Versions/Battle.net.app'")

  Thread.setDefaultUncaughtExceptionHandler((t, e) => e.printStackTrace())
}
