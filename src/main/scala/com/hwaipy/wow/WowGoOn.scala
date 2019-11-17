package com.hwaipy.wow

import java.awt.{Point, Rectangle}
import java.io.{File, FileReader, PrintWriter}
import java.util.{Properties, Timer, TimerTask}
import java.util.concurrent.Executors

import scalafx.application.JFXApp
import scalafx.application.JFXApp.PrimaryStage
import scalafx.geometry.{Insets, Pos}
import scalafx.scene.Scene
import scalafx.scene.control.{Button, ToggleButton}
import scalafx.scene.layout.{AnchorPane, HBox}
import scalafx.stage.{FileChooser, Screen, StageStyle}
import scalafx.Includes._
import scalafx.beans.property.{BooleanProperty, LongProperty, ObjectProperty, StringProperty}

import scala.concurrent.{ExecutionContext, Future}
import scala.language.postfixOps

object WowGoOn extends JFXApp {
  val visualBounds = Screen.primary.visualBounds
  private val properties = new Properties()
  private val battleNetPath = new StringProperty("")
  private val battleNetPathValid = new BooleanProperty()
  battleNetPath.onChange((a, b, c) => battleNetPathValid.value = new File(c).exists())
  WowGo.battleNetPath <== battleNetPath
  private val lockedOn = new BooleanProperty()
  private val fishPaneVisible = new BooleanProperty()
  private val fishPaneClock = new LongProperty()
  private val fishPaneTimer = new Timer()
  fishPaneTimer.schedule(new TimerTask {
    override def run(): Unit = fishPaneVisible set (System.currentTimeMillis() < fishPaneClock.get + 1000)
  }, 1000, 100)
  private val fishPaneRectangle = new ObjectProperty[Rectangle]()
  private val fishPaneTarget = new ObjectProperty[Point]()

  loadProperties()

  val actionDimension = (visualBounds.width * 0.4 + properties.getProperty("UI.Action.WidthExt", "0").toDouble,
    visualBounds.height * 0.4 + properties.getProperty("UI.Action.HeightExt", "0").toDouble)
  //  val actionBounds = (
  //    (visualBounds.width - actionDimension._1) / 2 + properties.getProperty("UI.Action.XExt", "0").toDouble,
  //    (visualBounds.height - actionDimension._2) / 2 + properties.getProperty("UI.Action.YExt", "0").toDouble,
  //    actionDimension._1, actionDimension._2)

  stage = new PrimaryStage {
    title = "WOW.GO"
    x = 0
    y = 0
    width = visualBounds.width
    height = visualBounds.height
    scene = new Scene {
      stylesheets.add(ClassLoader.getSystemClassLoader.getResource("com/hwaipy/wow/PD.css").toExternalForm)
      root = new AnchorPane {
        styleClass += "rootPane"

        val configPane = new HBox {
          alignment = Pos.Center
          spacing = 10
          padding = Insets(10, 10, 10, 10)
          styleClass += "configPane"
          prefHeight = 50

          val quitButton = new Button("Quit") {
            onAction = () => {
              WowGo.exit()
              exit()
              stage.close()
            }
          }
          val lockOnButton = new ToggleButton("Lock On") {
            disable <== battleNetPathValid.not() or (WowGo.runningProperty and selected.not())
            lockedOn <== selected
            onAction = () => {}
          }
          val selectBattleNetButton = new Button("Select Battle.Net") {
            disable <== lockOnButton.selected or WowGo.runningProperty
            val fileChooser = new FileChooser()
            fileChooser.getExtensionFilters().addAll(new FileChooser.ExtensionFilter("Battle.Net", "Battle.net.exe"))
            onAction = () => {
              if (battleNetPathValid.value) {
                try {
                  fileChooser.setInitialDirectory(new File(battleNetPath.value).getParentFile)
                } catch {
                  case e: Throwable =>
                }
              }
              val selectedFile = fileChooser.showOpenDialog(stage)
              if (selectedFile != null) {
                properties.put("Battle.Net", selectedFile.getAbsolutePath)
                saveProperties()
                loadProperties()
              }
            }
          }
          val runButton = new Button("Run WOW") {
            disable <== battleNetPathValid.not() or lockOnButton.selected or WowGo.runningProperty
            onAction = () => WowGo.runLater("ACTION_REOPEN")
          }
          val testButton = new Button("Test") {
            onAction = () => {
              //              showTargetRectangle()
              WowGo.run("TEST")
            }
          }
          children =
            Seq(
              selectBattleNetButton, runButton, lockOnButton,
              testButton,
              new AnchorPane {
                prefWidth = 20
              },
              quitButton
            )
        }
        val configPaneContainer = new HBox {
          alignment = Pos.Center
          padding = Insets(0, 0, 0, 0)
          styleClass += "configPaneContainer"
          prefHeight = 50 + properties.getProperty("UI.Config.HeightExt", "0").toDouble
          prefWidth = 1000 + visualBounds.width
          children = Seq(configPane)
        }
        val actionPane = new AnchorPane {
          styleClass += "actionPane"
          prefHeight = 10
          prefWidth = 10
          visible <== fishPaneVisible

          val targetPane = new AnchorPane() {
            styleClass += "targetPane"
            prefWidth = 120 + properties.getProperty("UI.Target.RExt", "0").toDouble
            prefHeight = prefWidth.value
          }
          //          targetPane.visible = false
          children = Seq(targetPane)
          fishPaneTarget onChange ((a, b, c) => {
            targetPane.visible = (c.x != 0 || c.y != 0)
            AnchorPane.setLeftAnchor(targetPane, c.x - targetPane.prefWidth.value / 2)
            AnchorPane.setTopAnchor(targetPane, c.y - targetPane.prefHeight.value / 2)
          })

          //          def showTargetPane(x: Double, y: Double) = {
          //            AnchorPane.setLeftAnchor(targetPane, x - targetPane.prefWidth.value / 2 + properties.getProperty("UI.Target.XExt", "0").toDouble)
          //            AnchorPane.setTopAnchor(targetPane, y - targetPane.prefHeight.value / 2 + properties.getProperty("UI.Target.YExt", "0").toDouble)
          //            targetPane.visible = true
          //          }
        }
        AnchorPane.setTopAnchor(configPaneContainer, 0)
        AnchorPane.setLeftAnchor(configPaneContainer, 0)
        AnchorPane.setRightAnchor(configPaneContainer, 0)
        AnchorPane.setTopAnchor(actionPane, 0)
        AnchorPane.setLeftAnchor(actionPane, 0)
        fishPaneRectangle onChange ((a, b, c) => {
          AnchorPane.setTopAnchor(actionPane, c.y)
          AnchorPane.setLeftAnchor(actionPane, c.x)
          actionPane.prefWidth = c.width
          actionPane.prefHeight = c.height
        })

        children = Seq(configPaneContainer, actionPane)
      }
    }
    scene.value.setFill(null)
  }
  stage.initStyle(StageStyle.Transparent)
  stage.alwaysOnTop = true

  def showFishRectangle(rectangle: Rectangle, targetPosition: Point) = {
    fishPaneRectangle set rectangle
    fishPaneTarget set targetPosition
    fishPaneClock set System.currentTimeMillis()
  }

  def loadProperties() = {
    val pIn = new FileReader("config.properties")
    properties.clear()
    properties.load(pIn)
    pIn.close()

    battleNetPath set properties.getProperty("Battle.Net", "")
  }

  def saveProperties() = {
    val pOut = new PrintWriter("config.properties")
    properties.store(pOut, "")
    pOut.close()
  }

  private val executor = Executors.newSingleThreadExecutor()
  private val executionContext = ExecutionContext.fromExecutorService(executor)
  Future[Unit] {
    while (!executor.isShutdown) {
      if (lockedOn get) {
        val delay = WowGo.run("LOCK_ON")
        if (delay > 0) Thread.sleep((delay * 1000).toLong)
      } else {
        Thread.sleep(1000)
      }
    }
  }(executionContext)

  def exit() = {
    executor.shutdown()
    fishPaneTimer.cancel()
  }
}