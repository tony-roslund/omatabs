import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "NotesModel.js" as NotesModel

BorderSurface {
  id: root

  property string colorId: "yellow"
  property bool isNew: true
  property string fontFamily: Style.font.menuFamily
  property int hang: 0
  property bool onRight: true

  readonly property var swatch: NotesModel.colorFor(colorId)
  readonly property color paper: swatch.paper
  readonly property color ink: swatch.ink
  readonly property var paperBorder: Border.surfaceSpec("menu", "border", Util.alpha(swatch.ink, 0.18), 1)

  signal saveRequested(string title, string body, string colorId)
  signal cancelRequested()
  signal deleteRequested()
  signal colorPicked(string id)

  color: paper
  borderSpec: paperBorder
  radius: Style.cornerRadius
  padding: Style.spacing.panelPadding

  function takeFocus() {
    titleField.forceActiveFocus()
  }

  function setDraft(title, body) {
    titleField.text = title || ""
    bodyEdit.text = body || ""
  }

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) {
      root.cancelRequested()
      event.accepted = true
    }
  }

  TextField {
    id: titleField
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.topMargin: root.contentTopInset
    anchors.leftMargin: root.contentLeftInset + (root.onRight ? 0 : root.hang)
    anchors.rightMargin: root.contentRightInset + (root.onRight ? root.hang : 0)
    foreground: root.ink
    placeholderText: "Title"
    font.bold: true
    font.pixelSize: Style.font.title
    background: Item {}
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape) {
        root.cancelRequested()
        event.accepted = true
        return
      }
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        root.saveRequested(titleField.text, bodyEdit.text, root.colorId)
        event.accepted = true
      }
    }
  }

  TextArea {
    id: bodyEdit
    anchors.top: titleField.bottom
    anchors.left: titleField.left
    anchors.right: titleField.right
    anchors.bottom: chrome.top
    anchors.topMargin: Style.spacing.sm
    anchors.bottomMargin: Style.spacing.sm
    wrapMode: TextArea.Wrap
    textFormat: TextEdit.PlainText
    placeholderText: "Write in markdown"
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    color: root.ink
    placeholderTextColor: Util.alpha(root.ink, 0.45)
    selectionColor: Style.selectionFillFor(root.ink, Color.accent)
    selectedTextColor: root.ink
    selectByMouse: true
    persistentSelection: true
    background: Item {}
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape) {
        root.cancelRequested()
        event.accepted = true
        return
      }
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        if (event.modifiers & Qt.ShiftModifier) {
          event.accepted = false
          return
        }
        root.saveRequested(titleField.text, bodyEdit.text, root.colorId)
        event.accepted = true
      }
    }
  }

  NoteChrome {
    id: chrome
    anchors.left: titleField.left
    anchors.right: titleField.right
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.contentBottomInset
    colorId: root.colorId
    ink: root.ink
    showDelete: true
    onColorPicked: function(id) { root.colorPicked(id) }
    onDeleteClicked: {
      if (root.isNew) root.cancelRequested()
      else root.deleteRequested()
    }
  }
}
