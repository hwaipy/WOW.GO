//enablePlugins(JavaServerAppPackaging, UniversalDeployPlugin, WindowsPlugin, WindowsDeployPlugin)

name := "PD"
version := "0.1.1"
scalaVersion := "2.12.8"
organization := "com.hydra"
libraryDependencies += "org.scalafx" %% "scalafx" % "11-R16"
libraryDependencies += "net.sourceforge.tess4j" % "tess4j" % "3.2.1"
// Determine OS version of JavaFX binaries
lazy val osName = System.getProperty("os.name") match {
  case n if n.startsWith("Linux") => "linux"
  case n if n.startsWith("Mac") => "mac"
  case n if n.startsWith("Windows") => "win"
  case _ => throw new Exception("Unknown platform!")
}
lazy val javaFXModules = Seq("base", "controls", "fxml", "graphics", "media", "swing", "web")
libraryDependencies ++= javaFXModules.map(m =>
  "org.openjfx" % s"javafx-$m" % "11" classifier osName
)

libraryDependencies += "org.scalatest" %% "scalatest" % "3.0.5" % "test"
scalacOptions ++= Seq("-feature")
scalacOptions ++= Seq("-deprecation")
scalacOptions ++= Seq("-Xlint")
fork := true
