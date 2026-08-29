import QtQuick
import qs.Commons

Item {
  id: root

  property string colorId: "yellow"
  property bool showDelete: true
  property color ink: "#2C2710"

  signal colorPicked(string id)
  signal deleteClicked()

  readonly property int dot: Style.space(16)

  height: Style.space(28)
  implicitHeight: height

  ListModel {
    id: paletteModel
    ListElement { swatchId: "yellow"; paper: "#F3E07A"; ink: "#2C2710" }
    ListElement { swatchId: "mint"; paper: "#B6E3C4"; ink: "#173022" }
    ListElement { swatchId: "blue"; paper: "#C7D8F0"; ink: "#1A2433" }
    ListElement { swatchId: "lavender"; paper: "#D9C4F0"; ink: "#2A1D33" }
    ListElement { swatchId: "peach"; paper: "#F2C4A8"; ink: "#332016" }
    ListElement { swatchId: "rose"; paper: "#F0C1D2"; ink: "#331820" }
  }

  Row {
    id: dots
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.spacing.sm

    Repeater {
      model: paletteModel
      delegate: Item {
        required property string swatchId
        required property string paper
        required property string ink
        width: root.dot + Style.space(6)
        height: root.dot + Style.space(6)

        Rectangle {
          anchors.centerIn: parent
          width: root.dot
          height: root.dot
          radius: width / 2
          color: paper
          border.width: root.colorId === swatchId ? 2 : 1
          border.color: root.colorId === swatchId ? ink : Qt.rgba(0, 0, 0, 0.22)
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.colorPicked(swatchId)
        }
      }
    }
  }

  Row {
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.spacing.md

    Text {
      visible: root.showDelete
      text: ""
      color: root.ink
      font.family: Style.font.family
      font.pixelSize: Style.font.iconLarge
      verticalAlignment: Text.AlignVCenter
      height: root.height
      opacity: 0.8

      MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: root.deleteClicked()
      }
    }
  }
}
