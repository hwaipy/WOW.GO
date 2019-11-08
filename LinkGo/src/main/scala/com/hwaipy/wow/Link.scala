package com.hwaipy.wow

import java.awt.Color
import java.awt.image.BufferedImage
import java.io.File

import javax.imageio.ImageIO

//import java.awt.event.{InputEvent, KeyEvent}
//import java.awt.{Color, Rectangle, Robot}
//import java.io.{File, FileReader}
//import java.util.Properties
//import java.util.concurrent.{Executors, ThreadFactory}
//import java.util.concurrent.atomic.AtomicBoolean
//
//import javax.imageio.ImageIO
//import scalafx.application.JFXApp.PrimaryStage
//import scalafx.geometry.Insets
//import scalafx.scene.layout._
//import scalafx.stage.{Screen, StageStyle}
//import scalafx.Includes._
//
//import scala.concurrent.{ExecutionContext, Future}
//import scalafx.application.JFXApp
//import scalafx.scene.Scene
//import scalafx.scene.control.{Button, CheckBox, Label, TextField, ToggleButton}
//
//import scala.collection.mutable.ListBuffer
//import scala.language.postfixOps
//import scala.util.Random
//
object LinkGo extends App {
  val root = "C:\\Users\\Administrator\\Desktop\\WOWT"
  val screenShot1 = new ScreenShot(ImageIO.read(new File(root, "1.png"))).blackEdged()
  val screenShot2 = new ScreenShot(ImageIO.read(new File(root, "2.png"))).blackEdged()
  val screenShot3 = new ScreenShot(ImageIO.read(new File(root, "3.png"))).blackEdged()

  //  val redButtonCondition = new BitWiseCondition((r, g, b) => r > 5 * g && r > 5 * b, 0.5)
  //
  //  val isCharacterSelecting = redButtonCondition.satisfied(screenShot1.subScreenShot(0.5, 0.918, 0.12, 0.04))
  //  val isAlert = redButtonCondition.satisfied(screenShot3.subScreenShot(0.5, 0.918, 0.12, 0.04))

  //  println(discCondition.satisfied(screenShot.subScreenShot(0.5, 0.51, 0.13, 0.03)))

  //  println(s"is character selecting: ${isCharacterSelecting}")
  //  ImageIO.write(screenShot3.subScreenShot(0.5, 0.51, 0.13, 0.03).image, "png", new File("testSub.png"))

  val ps = new PatternSearcher(screenShot1)
}

class ScreenShot(val image: BufferedImage) {
  val sampleCount = image.getWidth * image.getHeight
  private lazy val data = {
    val bytes = new Array[Int](sampleCount * 3)
    image.getData.getPixels(0, 0, image.getWidth, image.getHeight, bytes)
    bytes
  }

  def subScreenShot(xCenter: Double, yCenter: Double, width: Double, height: Double) = new ScreenShot(image.getSubimage(((xCenter - width / 2) * image.getWidth).toInt, ((yCenter - height / 2) * image.getHeight).toInt, (width * image.getWidth).toInt, (height * image.getHeight).toInt))

  def getR(index: Int) = data(index * 3)

  def getG(index: Int) = data(index * 3 + 1)

  def getB(index: Int) = data(index * 3 + 2)

  def getRGBTuple(x: Int, y: Int): Tuple3[Int, Int, Int] = getRGBTuple(x + image.getWidth * y)

  def getRGBTuple(index: Int): Tuple3[Int, Int, Int] = (data(index * 3), data(index * 3 + 1), data(index * 3 + 2))

  def getRGB(index: Int): Int = new Color(data(index * 3), data(index * 3 + 1), data(index * 3 + 2)).getRGB

  def getRGB(x: Int, y: Int): Int = getRGB(x + image.getWidth * y)

  def getRGBRow(y: Int) = Range(0, image.getWidth()).map(x => getRGB(x, y)).toArray

  def getRGBColumn(x: Int) = Range(0, image.getHeight()).map(y => getRGB(x, y)).toArray

  def blackEdged() = {
    val black = Color.BLACK.getRGB
    val columnLeft = getRGBColumn(0).map(i => i == black)
    val columnLeftTop = columnLeft.slice(0, columnLeft.size / 2)
    val columnLeftBottom = columnLeft.slice(columnLeft.size / 2, columnLeft.size)
    val marginTop = columnLeftTop.size - columnLeftTop.reverse.indexOf(false)
    val marginBottom = columnLeftBottom.size - columnLeftBottom.indexOf(false)
    val rowCenter = getRGBRow(image.getHeight() / 2).map(i => i == black)
    val marginLeft = rowCenter.indexOf(false)
    val marginRight = rowCenter.reverse.indexOf(false)
    new ScreenShot(image.getSubimage(marginLeft, marginTop, image.getWidth - marginLeft - marginRight, image.getHeight - marginTop - marginBottom))
  }
}

abstract class Condition {
  def satisfied(screenShot: ScreenShot): Boolean
}

class BitWiseCondition(bitWiseCondition: (Int, Int, Int) => Boolean, threshold: Double) extends Condition {
  def satisfied(screenShot: ScreenShot) = Range(0, screenShot.sampleCount).map(i => bitWiseCondition(screenShot.getR(i), screenShot.getG(i), screenShot.getB(i))).filter(i => i).size > threshold * screenShot.sampleCount
}

class PatternSearcher(screenShot: ScreenShot) {
  val start = System.nanoTime()

  screenShot.d

  val stop = System.nanoTime()
  println(s"Calculation finished in ${(stop - start) / 1e6} ms.")
}