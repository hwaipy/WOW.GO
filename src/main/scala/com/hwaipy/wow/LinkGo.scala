package com.hwaipy.wow

import java.awt.Color
import java.awt.geom.AffineTransform
import java.awt.image.BufferedImage
import java.io.File
import javax.imageio.ImageIO
import scala.collection.mutable.ListBuffer

object LinkGo {
  def status(image: BufferedImage) = {
    val ps = new PatternSearcher(ScreenShot(image))
    ps.status
  } match {
    case "QUEUE" => if (new PatternSearcher(ScreenShot(image, false)).checkQueueStatus) "QUEUE" else "ERROR"
    case s => s
  }
}

object FishGo {
  def capture(image: BufferedImage, thresholds: Tuple3[Double, Double, Double]) = {
    val screenShot = new ScreenShot(image)
    val hotSpots = Range(0, image.getWidth * image.getHeight).map(i => {
      val rgb = screenShot.getRGBTuple(i)
      if (rgb._1 > rgb._2 * thresholds._1 && rgb._1 > rgb._3 * thresholds._2 && rgb._2 > rgb._3 * thresholds._3) 1 else 0
    }).toArray
//    if (true) {
//      ImageIO.write(screenShot.image, "png", new File("SS.png"))
//      for (x <- 0 until screenShot.image.getWidth) {
//        for (y <- 0 until screenShot.image.getHeight) {
//          if (hotSpots(y * screenShot.image.getWidth + x) > 0) screenShot.image.setRGB(x, y, Color.BLACK.getRGB)
//          else screenShot.image.setRGB(x, y, Color.WHITE.getRGB)
//        }
//      }
//      ImageIO.write(screenShot.image, "png", new File("SSF.png"))
//    }
    var centerXSum = 0
    var centerYSum = 0
    var weight = 0
    for (x <- 0 until image.getWidth) {
      for (y <- 0 until image.getHeight) {
        if (hotSpots(y * image.getWidth + x) > 0) {
          centerXSum += x
          centerYSum += y
          weight += 1
        }
      }
    }
    val center = (centerXSum.toDouble / weight, centerYSum.toDouble / weight)
    center
  }
}

object ScreenShot {
  val resizeWidth = 500

  def apply(originalImage: BufferedImage, resize: Boolean = true) = {
    val scale = if (resize) resizeWidth.toDouble / originalImage.getWidth else 1
    val img = new BufferedImage((scale * originalImage.getWidth()).toInt, (scale * originalImage.getHeight()).toInt, BufferedImage.TYPE_INT_RGB)
    val g2 = img.createGraphics()
    g2.drawImage(originalImage, AffineTransform.getScaleInstance(scale, scale), null)
    g2.dispose()
    new ScreenShot(img)
  }
}

class ScreenShot(val image: BufferedImage) {
  val sampleCount = image.getWidth * image.getHeight
  val width = image.getWidth()
  val height = image.getHeight()
  lazy val data = {
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

class PatternSearcher(val screenShot: ScreenShot) {
  val width = screenShot.width
  val height = screenShot.height
  //  private val start = System.nanoTime()

  private val suspiciousSpots = Range(0, width * height).map(i => {
    val rgb = screenShot.getRGBTuple(i)
    if (rgb._1 > 5 * rgb._2 && rgb._1 > 5 * rgb._3) 1 else 0
  }).toArray
  private val targetSpots = suspiciousSpots.map(_ => 0)
  private val suspiciousSpotsOriginal = suspiciousSpots.map(i => i)

  private def suspiciousCount(x: Int, y: Int, w: Int, h: Int) = Range(x, x + w).map(ix => Range(y, y + h).map(iy => suspiciousSpots(iy * width + ix)).sum).sum

  private def firstSuspiciousSpot = {
    val i = suspiciousSpots.indexOf(1)
    (i % width, (i / width))
  }

  private def dye(x: Int, y: Int, w: Int, h: Int, refused: Boolean) = Range(x, x + w).map(ix => Range(y, y + h).map(iy => {
    val i = iy * width + ix
    suspiciousSpots(i) = 0
    if (!refused) targetSpots(i) = 1
  }))

  private def diffusion(xStart: Int, yStart: Int) = {
    val step = 2
    var left = xStart
    var top = yStart
    var right = left + 1
    var bottom = top + 1
    var count = suspiciousCount(left, top, right - left, bottom - top)
    var direction = 0
    var lastUpdated = 0
    while (lastUpdated < 10) {
      var nLeft = left
      var nTop = top
      var nRight = right
      var nBottom = bottom
      direction match {
        case 0 => nLeft -= step
        case 1 => nTop -= step
        case 2 => nRight += step
        case 3 => nBottom += step
      }
      direction = (direction + 1) % 4
      if (nLeft < 0) nLeft = 0
      if (nTop < 0) nTop = 0
      if (nRight >= width) nRight = width
      if (nBottom >= height) nBottom = height
      val newCount = suspiciousCount(nLeft, nTop, nRight - nLeft, nBottom - nTop)
      if (newCount > count) {
        count = newCount
        lastUpdated = 0
        left = nLeft
        top = nTop
        right = nRight
        bottom = nBottom
      } else lastUpdated += 1
    }
    (left, top, right - left, bottom - top)
  }

  private lazy val buttons = {
    val buttonBuffer = new ListBuffer[Tuple4[Int, Int, Int, Int]]()
    var end = 1
    while (end > 0) {
      val fss = firstSuspiciousSpot
      if (fss._1 >= 0) {
        val diffusioned = diffusion(fss._1, fss._2)
        val validButton = (diffusioned._3 > 3 * diffusioned._4) && (diffusioned._3 > width * 0.03) && (diffusioned._4 > height * 0.005)
        dye(diffusioned._1, diffusioned._2, diffusioned._3, diffusioned._4, !validButton)
        if (validButton) {
          buttonBuffer += diffusioned
        }
        end = 1
      } else end = 0
    }
    buttonBuffer.toList
  }

  def createTargetSpotImage = {
    val imageS = new BufferedImage(width, height, BufferedImage.TYPE_INT_ARGB)
    val imageSO = new BufferedImage(width, height, BufferedImage.TYPE_INT_ARGB)
    val imageT = new BufferedImage(width, height, BufferedImage.TYPE_INT_ARGB)
    Range(0, height).foreach(y => Range(0, width).foreach(x => {
      imageS.setRGB(x, y, suspiciousSpots(y * width + x) match {
        case 1 => Color.BLACK.getRGB
        case 0 => Color.WHITE.getRGB
      })
      imageSO.setRGB(x, y, suspiciousSpotsOriginal(y * width + x) match {
        case 1 => Color.BLACK.getRGB
        case 0 => Color.WHITE.getRGB
      })
      imageT.setRGB(x, y, targetSpots(y * width + x) match {
        case 1 => Color.BLACK.getRGB
        case 0 => Color.WHITE.getRGB
      })
    }))
    imageT
  }

  def saveTargetSpotImage(filename: String) = ImageIO.write(createTargetSpotImage, "png", new File(filename))

  private val buttonBegin = (0.5, 0.895)
  private val buttonLogin = (0.5, 0.689)
  private val buttonError = (0.5, 0.507)
  private val buttonQueue = (0.5, 0.543)

  private def hasButton(posision: Tuple2[Double, Double], error: Double = 10) = {
    val x = (posision._1 * width).toInt
    val y = (posision._2 * height).toInt
    buttons.map(button => (x >= button._1 - error) && (x <= button._1 + button._3 + error) && (y >= button._2 - error) && (y <= button._2 + button._4 + error)).contains(true)
  }

  def status =
    if (hasButton(buttonQueue)) "QUEUE"
    else if (hasButton(buttonError)) "ERROR"
    else if (hasButton(buttonLogin)) "LOGIN"
    else if (hasButton(buttonBegin)) "BEGIN"
    else "NORMAL"

  def checkQueueStatus = {
    val subScreenShot = screenShot.subScreenShot(0.5, 0.47, 0.15, 0.08)
    val subWidth = subScreenShot.width
    val subHeight = subScreenShot.height
    val yellowRows = Range(0, subHeight).map(y => Range(0, subWidth).map(x => {
      val rgb = subScreenShot.getRGBTuple(x, y)
      if (rgb._1 > 200 && rgb._2 > 160 && rgb._3 < 110) 1 else 0
    }).sum)
    val yellowRowDiffed = Range(1, yellowRows.size - 1).map(i => yellowRows(i) > 5 || yellowRows(i - 1) > 5 || yellowRows(i + 1) > 5)
    val yellowRowSections = {
      val buffer = new ListBuffer[Tuple2[Int, Int]]()
      var position = 0
      while (position >= 0) {
        val end = position + yellowRowDiffed.slice(position, yellowRowDiffed.size).indexOf(!yellowRowDiffed(position))
        if (yellowRowDiffed(position)) buffer += ((position, end))
        position = if (end < position) -1 else end
      }
      buffer.toList
    }
    yellowRowSections.size == 3
  }
}