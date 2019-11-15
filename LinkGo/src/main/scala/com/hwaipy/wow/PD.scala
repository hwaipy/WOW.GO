//package com.hwaipy.wow
//
//import java.awt.event.{InputEvent, KeyEvent}
//import java.awt.{Color, Rectangle, Robot, Toolkit}
//import java.io.{File, FileReader}
//import java.util.Properties
//import java.util.concurrent.{Executors, ThreadFactory}
//import java.util.concurrent.atomic.{AtomicBoolean, AtomicLong, AtomicReference}
//
//import javax.imageio.ImageIO
//import scalafx.application.JFXApp.PrimaryStage
//import scalafx.geometry.Insets
//import scalafx.scene.layout._
//import scalafx.stage.{Screen, StageStyle}
//import scalafx.Includes._
//
//import scala.concurrent.{ExecutionContext, Future}
//import scalafx.application.{JFXApp, Platform}
//import scalafx.scene.Scene
//import scalafx.scene.control.{Button, CheckBox, Label, TextField, ToggleButton}
//
//import scala.collection.mutable.ListBuffer
////import scala.language.reflectiveCalls
//import scala.language.postfixOps
//import scala.util.Random
//
//object PD extends JFXApp {
//  val properties = new Properties()
//  val pIn = new FileReader("config.txt")
//  properties.load(pIn)
//  pIn.close()
//  val executionContext = ExecutionContext.fromExecutor(Executors.newSingleThreadExecutor(new ThreadFactory {
//    override def newThread(r: Runnable): Thread = {
//      val t = new Thread(r, s"Fisher Thread")
//      t.setDaemon(true)
//      t.setUncaughtExceptionHandler((t: Thread, e: Throwable) => e.printStackTrace())
//      t
//    }
//  }))
//  val robot = new Robot()
//  val random = new Random()
//  val visualBounds = Screen.primary.visualBounds
//  val actionDimension = (visualBounds.width * 0.4 + properties.getProperty("UI.Action.WidthExt", "0").toDouble,
//    visualBounds.height * 0.4 + properties.getProperty("UI.Action.HeightExt", "0").toDouble)
//  val actionBounds = (
//    (visualBounds.width - actionDimension._1) / 2 + properties.getProperty("UI.Action.XExt", "0").toDouble,
//    (visualBounds.height - actionDimension._2) / 2 + properties.getProperty("UI.Action.YExt", "0").toDouble,
//    actionDimension._1, actionDimension._2)
//  val captureBounds = (
//    (actionBounds._1 + properties.getProperty("UI.Capture.XExt", "0").toDouble).toInt,
//    (actionBounds._2 + properties.getProperty("UI.Capture.YExt", "0").toDouble).toInt,
//    (actionBounds._3 + properties.getProperty("UI.Capture.WidthExt", "0").toDouble).toInt,
//    (actionBounds._4 + properties.getProperty("UI.Capture.HeightExt", "0").toDouble).toInt
//  )
//  val cellCountX = properties.getProperty("Package.Count.X", "5").toInt
//  val cellCountY = properties.getProperty("Package.Count.Y", "5").toInt
//  val cellSize = properties.getProperty("Package.Cell.Size", "25").toDouble
//  val cellCount = properties.getProperty("Package.Cell.Count", "80").toInt
//  val packagePosition = (
//    visualBounds.width * 0.05 - properties.getProperty("UI.Package.XExt", "0").toDouble,
//    visualBounds.height * 0.4 + properties.getProperty("UI.Package.YExt", "0").toDouble
//  )
//  val loopDelay = properties.getProperty("LinkGo.Loop.Delay", "5000").toLong
//  val fishEnabled = properties.getProperty("Fish.Go", "false").toBoolean
//  val battleNetPath = properties.getProperty("Battle.Net", "Battle.net.exe")
//
//  val fishing = new AtomicBoolean(false)
//  val autoOpenShell = new AtomicBoolean(false)
//  val autoReconnect = new AtomicBoolean(false)
//  val exited = new AtomicBoolean(false)
//  var positionShower: (Double, Double) => Unit = null
//  var thresholdR2G = 1.0
//  var thresholdR2B = 1.0
//  var thresholdG2B = 1.0
//  val linkStatusLabelLink = new AtomicReference[Label](null)
//
//  val linkCheckTimeStamp = new AtomicLong(0)
//
//  def linkCheck() = {
//    val currentTime = System.currentTimeMillis()
//    if (currentTime - linkCheckTimeStamp.get > loopDelay) {
//      linkCheckTimeStamp set currentTime
//      val screenSize = Toolkit.getDefaultToolkit.getScreenSize
//      val linkStatus = LinkGo.status(robot.createScreenCapture(new Rectangle(0, 0, screenSize.width, screenSize.height)))
//      println(linkStatus)
//      Platform.runLater(() => linkStatusLabelLink.get.text = linkStatus)
//
//      linkStatus match {
//        case "QUEUE" =>
//        case "ERROR" => linkReopen(2)
//        case "LOGIN" => linkReopen(1)
//        case "BEGIN" => actionKeyClick(KeyEvent.VK_ENTER)
//        case "NORMAL" =>
//      }
//    }
//  }
//
//  def linkReopen(c: Int) = {
//    linkCheckTimeStamp set System.currentTimeMillis()
//    Range(0, c).foreach(_ => {
//      actionKeyClick(KeyEvent.VK_ESCAPE)
//      delay(1000, 1500)
//    })
//    delay(1000, 1500)
//    Runtime.getRuntime.exec(battleNetPath)
//    delay(8000, 9500)
//    actionKeyClick(KeyEvent.VK_ENTER)
//    linkCheckTimeStamp set System.currentTimeMillis()
//  }
//
//  Future[Unit] {
//    var status = "Ready"
//    var waitingStart = 0l
//    val ysP = new ListBuffer[Double]()
//    val ysW = new ListBuffer[Double]()
//    while (!exited.get) {
//      if (!fishing.get) {
//        delay(1000)
//        status = "Ready"
//        if(autoReconnect.get) linkCheck()
//      }
//      else {
//        status match {
//          case "Ready" => {
//            ysP.clear()
//            ysW.clear()
//            actionMouseClick(visualBounds.width / 2 + random.nextInt(30), visualBounds.height / 2 + random.nextInt(30))
//            //            actionKeyClick(KeyEvent.VK_ENTER)
//            actionKeyClick(KeyEvent.VK_2)
//            delay(3000)
//            status = "Prepare"
//            waitingStart = System.nanoTime()
//          }
//          case "Prepare" => {
//            val waited = (System.nanoTime() - waitingStart) / 1e9
//            if (waited > 3) status = "Waiting"
//            else {
//              ysP += capture()._2
//            }
//          }
//          case "Waiting" => {
//            val waited = (System.nanoTime() - waitingStart) / 1e9
//            if (waited > 25) status = "Ready"
//            else {
//              ysW += capture()._2
//              if (ysW.max - ysW.min > 2 * (ysP.max - ysP.min)) {
//                delay(800, 1600)
//                val position = capture()
//                actionMouseClick(position._1 + captureBounds._1, position._2 + captureBounds._2, false)
//                delay(1000, 2000)
//                if (random.nextDouble() < 0.05) actionKeyClick(KeyEvent.VK_1)
//                if (random.nextDouble() < 0.85) {
//                  if (autoOpenShell get) {
//                    delay(1000, 1500)
//                    actionMouseClickPackage(-1, false)
//                  }
//                  actionKeyClick(KeyEvent.VK_SPACE)
//                  delay(3000, 4500)
//                }
//                status = "Ready"
//              }
//            }
//          }
//        }
//      }
//    }
//  }(executionContext)
//
//  stage = new PrimaryStage {
//    title = "WOW.GO"
//    x = 0
//    y = 0
//    width = visualBounds.width
//    height = visualBounds.height
//    scene = new Scene {
//      stylesheets.add(ClassLoader.getSystemClassLoader.getResource("com/hwaipy/wow/PD.css").toExternalForm)
//      root = new AnchorPane {
//        styleClass += "rootPane"
//        val configPane = new HBox {
//          spacing = 10
//          padding = Insets(10, 10, 10, 10)
//          styleClass += "configPane"
//          prefHeight = 50 + properties.getProperty("UI.Config.HeightExt", "0").toDouble
//          prefWidth = (if(fishEnabled) 1000 else 500) + properties.getProperty("UI.Config.WidthExt", "0").toDouble
//
//          val quitButton = new Button("Quit") {
//            onAction = () => {
//              exited set true
//              stage.close()
//            }
//          }
//          val openButton = new Button("Open") {
//            onAction = () => {
//              disable = true
//              new Thread(()=>{
//                linkReopen(0)
//                Platform.runLater(()=> disable = false)
//              }).start()
//            }
//          }
//          val snapshotButton = new Button("Snapshot") {
//            onAction = () => {
//              val center = capture(true)
//              actionMouseClick(center._1 + captureBounds._1, center._2 + captureBounds._2)
//              actionMouseClickPackage(-1, false)
//            }
//          }
//          val fishingButton = new ToggleButton("Go Fish") {
//            onAction = () => {
//              fishing set this.selected.value
//            }
//          }
//          val autoOpenShellCheckBox = new CheckBox("Auto Open&Eat") {
//            style = "-fx-text-fill: black;"
//            onAction = () => {
//              autoOpenShell set this.selected.value
//            }
//          }
//          val autoReconnectCheckBox = new CheckBox("Auto Reconnect") {
//            style = "-fx-text-fill: black;"
//            onAction = () => {
//              autoReconnect set this.selected.value
//            }
//          }
//          val thresholdFieldG2B = new TextField() {
//            prefWidth = 40
//            text = "1.0"
//            text.onChange((a, b, c) => {
//              try {
//                thresholdG2B = c.toDouble
//              } catch {
//                case e: Throwable =>
//              }
//            })
//          }
//          val thresholdFieldR2G = new TextField() {
//            prefWidth = 40
//            text = "1.0"
//            text.onChange((a, b, c) => {
//              try {
//                thresholdR2G = c.toDouble
//              } catch {
//                case e: Throwable =>
//              }
//            })
//          }
//          val thresholdFieldR2B = new TextField() {
//            prefWidth = 40
//            text = "0"
//            text.onChange((a, b, c) => {
//              try {
//                thresholdR2B = c.toDouble
//              } catch {
//                case e: Throwable =>
//              }
//            })
//          }
//          val labelG2B = new Label("G:B") {
//            style = "-fx-text-fill: black;"
//          }
//          val labelR2B = new Label("R:B") {
//            style = "-fx-text-fill: black;"
//          }
//          val labelR2G = new Label("R:G") {
//            style = "-fx-text-fill: black;"
//          }
//          val labelStatus = new Label("Normal") {
//            style = "-fx-text-fill: black;"
//            prefWidth = 60
//          }
//          linkStatusLabelLink set labelStatus
//          children = if (fishEnabled)
//            Seq(
//            openButton,
//            autoReconnectCheckBox,
//            labelStatus,
//            new AnchorPane {
//              prefWidth = 20
//            },
//            snapshotButton,
//            fishingButton,
//            new AnchorPane {
//              prefWidth = 20
//            },
//            autoOpenShellCheckBox,
//            new AnchorPane {
//              prefWidth = 20
//            },
//            labelR2G,
//            thresholdFieldR2G,
//            labelR2B,
//            thresholdFieldR2B,
//            labelG2B,
//            thresholdFieldG2B,
//            new AnchorPane {
//              prefWidth = 20
//            },
//            quitButton)
//          else
//            Seq(
//              openButton,
//              autoReconnectCheckBox,
//              labelStatus,
//              new AnchorPane {
//                prefWidth = 20
//              },
//              quitButton)
//        }
//        val actionPane = new AnchorPane {
//          styleClass += "actionPane"
//          prefHeight = actionBounds._4
//          prefWidth = actionBounds._3
//
//          val targetPane = new AnchorPane() {
//            styleClass += "targetPane"
//            prefWidth = 120 + properties.getProperty("UI.Target.RExt", "0").toDouble
//            prefHeight = prefWidth.value
//          }
//          targetPane.visible = false
//          children = Seq(targetPane)
//
//          def showTargetPane(x: Double, y: Double) = {
//            AnchorPane.setLeftAnchor(targetPane, x - targetPane.prefWidth.value / 2 + properties.getProperty("UI.Target.XExt", "0").toDouble)
//            AnchorPane.setTopAnchor(targetPane, y - targetPane.prefHeight.value / 2 + properties.getProperty("UI.Target.YExt", "0").toDouble)
//            targetPane.visible = true
//          }
//
//          positionShower = showTargetPane
//        }
//        val packagePane = new AnchorPane {
//          styleClass += "packagePane"
//
//          prefHeight = cellSize * cellCountY
//          prefWidth = cellSize * cellCountX
//
//          children = Range(0, cellCountX).map(x => Range(0, cellCountY).map(y => {
//            val packageCellPane = new AnchorPane {
//              styleClass += "packageCellPane"
//              prefHeight = cellSize
//              prefWidth = cellSize
//            }
//            AnchorPane.setLeftAnchor(packageCellPane, cellSize * x)
//            AnchorPane.setTopAnchor(packageCellPane, cellSize * y)
//            packageCellPane
//          })).flatten
//        }
//        AnchorPane.setTopAnchor(configPane, properties.getProperty("UI.Config.YExt", "0").toDouble)
//        AnchorPane.setLeftAnchor(configPane, (visualBounds.width - configPane.prefWidth.value) / 2 + properties.getProperty("UI.Config.XExt", "0").toDouble)
//        AnchorPane.setTopAnchor(actionPane, actionBounds._2)
//        AnchorPane.setLeftAnchor(actionPane, actionBounds._1)
//        AnchorPane.setTopAnchor(packagePane, packagePosition._2)
//        AnchorPane.setRightAnchor(packagePane, packagePosition._1)
//
//        children = if(fishEnabled)Seq(configPane, actionPane, packagePane)else Seq(configPane)
//      }
//    }
//    scene.value.setFill(null)
//  }
//  stage.initStyle(StageStyle.Transparent)
//  stage.alwaysOnTop = true
//
//  def capture(snapshotFile: Boolean = false) = {
//    val screenCapture = robot.createScreenCapture(new Rectangle(captureBounds._1, captureBounds._2, captureBounds._3, captureBounds._4))
//    val originalData = new Array[Int](screenCapture.getWidth * screenCapture.getHeight * 3)
//    screenCapture.getData.getPixels(0, 0, screenCapture.getWidth, screenCapture.getHeight, originalData)
//    val filteredData = new Array[Int](screenCapture.getWidth * screenCapture.getHeight)
//    for (i <- 0 until filteredData.size) {
//      filteredData(i) = if (originalData(i * 3) > originalData(i * 3 + 1) * thresholdR2G && originalData(i * 3 + 1) > originalData(i * 3 + 2) * thresholdG2B && originalData(i * 3) > originalData(i * 3 + 2) * thresholdR2B) 1 else 0
//      //      filteredData(i) = if (originalData(i * 3) > originalData(i * 3 + 1) && originalData(i * 3) > originalData(i * 3 + 2)) 1 else 0
//    }
//
//    if (snapshotFile) {
//      ImageIO.write(screenCapture, "png", new File("SS.png"))
//      for (x <- 0 until screenCapture.getWidth) {
//        for (y <- 0 until screenCapture.getHeight) {
//          if (filteredData(y * screenCapture.getWidth + x) > 0) screenCapture.setRGB(x, y, Color.BLACK.getRGB)
//          else screenCapture.setRGB(x, y, Color.WHITE.getRGB)
//        }
//      }
//      ImageIO.write(screenCapture, "png", new File("SSF.png"))
//    }
//
//    var centerXSum = 0
//    var centerYSum = 0
//    var weight = 0
//    for (x <- 0 until screenCapture.getWidth) {
//      for (y <- 0 until screenCapture.getHeight) {
//        if (filteredData(y * screenCapture.getWidth + x) > 0) {
//          centerXSum += x
//          centerYSum += y
//          weight += 1
//        }
//      }
//    }
//    val center = (centerXSum.toDouble / weight, centerYSum.toDouble / weight)
//    positionShower(center._1, center._2)
//    center
//  }
//
//  def actionKeyClick(keyCode: Int) = {
//    robot.keyPress(keyCode)
//    delay(50, 100)
//    robot.keyRelease(keyCode)
//    delay(50, 100)
//  }
//
//  def delay(from: Int, to: Int = -1) = if (to > from) Thread.sleep(random.nextInt(to - from) + from) else Thread.sleep(from)
//
//  def actionMouseClickPackage(slot: Int, isLeft: Boolean = true) = {
//    val actualSlot = if (slot >= 0) slot else slot + cellCount
//    val y = (actualSlot / cellCountX).toInt
//    val x = actualSlot % cellCountX
//    println(s"$x, $y")
//    actionMouseClick(
//      visualBounds.width - packagePosition._1 + properties.getProperty("UI.Capture.XExt", "0").toDouble + cellSize * (-cellCountX + 0.5 + x),
//      packagePosition._2 + properties.getProperty("UI.Capture.YExt", "0").toDouble + cellSize * (y + 0.5), false)
//  }
//
//  def actionMouseClick(x: Double, y: Double, isLeft: Boolean = true) = {
//    val button = if (isLeft) InputEvent.BUTTON1_DOWN_MASK else InputEvent.BUTTON3_DOWN_MASK
//    robot.mouseMove(x.toInt, y.toInt)
//    delay(50, 100)
//    robot.mousePress(button)
//    delay(50, 100)
//    robot.mouseRelease(button)
//    delay(50, 100)
//  }
//}