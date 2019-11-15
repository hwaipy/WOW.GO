package com.hwaipy.wow

import java.io.{File, FileReader, PrintWriter}
import java.util.Properties

import scalafx.application.JFXApp
import scalafx.application.JFXApp.PrimaryStage
import scalafx.geometry.{Insets, Pos}
import scalafx.scene.Scene
import scalafx.scene.control.{Button, CheckBox, Label, ToggleButton}
import scalafx.scene.layout.{AnchorPane, HBox, Region}
import scalafx.stage.{FileChooser, Screen, StageStyle}
import scalafx.Includes._
import scalafx.beans.property.{BooleanProperty, StringProperty}

object WowGoOn extends JFXApp {
  //  WowGo.run()
  private val visualBounds = Screen.primary.visualBounds
  private val properties = new Properties()
  private val battleNetPath = new StringProperty("")
  loadProperties()

  val actionDimension = (visualBounds.width * 0.4 + properties.getProperty("UI.Action.WidthExt", "0").toDouble,
    visualBounds.height * 0.4 + properties.getProperty("UI.Action.HeightExt", "0").toDouble)
  val actionBounds = (
    (visualBounds.width - actionDimension._1) / 2 + properties.getProperty("UI.Action.XExt", "0").toDouble,
    (visualBounds.height - actionDimension._2) / 2 + properties.getProperty("UI.Action.YExt", "0").toDouble,
    actionDimension._1, actionDimension._2)

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
          prefHeight = 50 + properties.getProperty("UI.Config.HeightExt", "0").toDouble

          val quitButton = new Button("Quit") {
            onAction = () => {
              //              exited set true
              stage.close()
            }
          }
          val lockOnButton = new ToggleButton("Lock On") {
            disable <== battleNetPath.===("")
            onAction = () => {
              //              fishing set this.selected.value
            }
          }
          val selectBattleNetButton = new Button("Select Battle.Net") {
            disable <== lockOnButton.selected
            val fileChooser = new FileChooser()
            //            fileChooser.setInitialDirectory(new File(properties.getProperty("Battle.Net", ".")))
            fileChooser.getExtensionFilters().addAll(new FileChooser.ExtensionFilter("Battle.Net", "Battle.net.exe"))
            onAction = () => {
              val selectedFile = fileChooser.showOpenDialog(stage)
              if (selectedFile != null) {
                properties.put("Battle.Net", selectedFile.getAbsolutePath)
                saveProperties()
                loadProperties()
              }
            }
          }
          val runButton = new Button("Run WOW") {
            disable <== battleNetPath.===("") or lockOnButton.selected
            onAction = () => {
              println("run!!!")
            }
          }
          val openButton = new Button("Open") {
            //            onAction = () => {
            //              disable = true
            //              new Thread(() => {
            //                linkReopen(0)
            //                Platform.runLater(() => disable = false)
            //              }).start()
            //            }
          }
          val snapshotButton = new Button("Snapshot") {
            //            onAction = () => {
            //              val center = capture(true)
            //              actionMouseClick(center._1 + captureBounds._1, center._2 + captureBounds._2)
            //              actionMouseClickPackage(-1, false)
            //            }
          }
          val fishingButton = new ToggleButton("Go Fish") {
            //            onAction = () => {
            //              fishing set this.selected.value
            //            }
          }
          val autoOpenShellCheckBox = new CheckBox("Auto Open&Eat") {
            style = "-fx-text-fill: black;"
            //            onAction = () => {
            //              autoOpenShell set this.selected.value
            //            }
          }
          val autoReconnectCheckBox = new CheckBox("Auto Reconnect") {
            style = "-fx-text-fill: black;"
            //            onAction = () => {
            //              autoReconnect set this.selected.value
            //            }
          }
          val labelStatus = new Label("Normal") {
            style = "-fx-text-fill: black;"
            prefWidth = 60
          }
          //          linkStatusLabelLink set labelStatus
          children =
            Seq(
              selectBattleNetButton, runButton, lockOnButton,
              //              openButton,
              //              autoReconnectCheckBox,
              //              labelStatus,
              //              new AnchorPane {
              //                prefWidth = 20
              //              },
              //              snapshotButton,
              //              fishingButton,
              //              new AnchorPane {
              //                prefWidth = 20
              //              },
              //              autoOpenShellCheckBox,
              //              new AnchorPane {
              //                prefWidth = 20
              //              },
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
          prefHeight = actionBounds._4
          prefWidth = actionBounds._3

          val targetPane = new AnchorPane() {
            styleClass += "targetPane"
            prefWidth = 120 + properties.getProperty("UI.Target.RExt", "0").toDouble
            prefHeight = prefWidth.value
          }
          targetPane.visible = false
          children = Seq(targetPane)

          def showTargetPane(x: Double, y: Double) = {
            AnchorPane.setLeftAnchor(targetPane, x - targetPane.prefWidth.value / 2 + properties.getProperty("UI.Target.XExt", "0").toDouble)
            AnchorPane.setTopAnchor(targetPane, y - targetPane.prefHeight.value / 2 + properties.getProperty("UI.Target.YExt", "0").toDouble)
            targetPane.visible = true
          }

          //          positionShower = showTargetPane
        }
        AnchorPane.setTopAnchor(configPaneContainer, 0)
        AnchorPane.setLeftAnchor(configPaneContainer, 0)
        AnchorPane.setRightAnchor(configPaneContainer, 0)
        AnchorPane.setTopAnchor(actionPane, actionBounds._2)
        AnchorPane.setLeftAnchor(actionPane, actionBounds._1)

        children = Seq(configPaneContainer, actionPane)
      }
    }
    scene.value.setFill(null)
  }
  stage.initStyle(StageStyle.Transparent)
  stage.alwaysOnTop = true

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
}