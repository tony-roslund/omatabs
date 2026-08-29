import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "NotesModel.js" as NotesModel

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property var notes: []
  property int notesRev: 0
  property string edge: "right"
  property bool editorOpen: false
  property bool editorIsNew: true
  property string editingId: ""
  property string draftTitle: ""
  property string draftBody: ""
  property string draftColor: "yellow"
  property string hoveredId: ""
  property bool plusHovered: false

  readonly property bool onRight: root.edge !== "left"
  readonly property int spineWidth: Style.space(28)
  readonly property int peekWidth: Style.space(240)
  readonly property int cardWidth: Style.space(300)
  readonly property int cardHeight: Style.space(280)
  readonly property int plusHeight: Style.space(20)
  readonly property int hang: Math.max(Style.cornerRadius, 4) + Math.max(2, Style.space(2))
  readonly property int dockWidth: root.hoveredId !== "" ? root.peekWidth : root.spineWidth
  readonly property color paper: Color.menu.background
  readonly property color ink: Color.menu.text
  readonly property var paperBorder: Border.flat(Color.menu.border, Math.max(1, Style.space(1)))
  readonly property string notesPath: Quickshell.env("HOME") + "/.local/state/omarchy/omatabs.json"

  function open(payloadJson) {
    root.startNew()
  }

  function close() {
    root.closeEditor()
  }

  function toggle() {
    if (root.editorOpen) root.closeEditor()
    else root.startNew()
  }

  function startNew() {
    root.editorIsNew = true
    root.editingId = ""
    root.draftTitle = ""
    root.draftBody = ""
    root.draftColor = NotesModel.nextColor(root.notes)
    root.hoveredId = ""
    root.plusHovered = false
    root.editorOpen = true
    Qt.callLater(function() {
      editorCard.setDraft("", "")
      editorCard.takeFocus()
    })
  }

  function editNote(id) {
    var note = NotesModel.findNote(root.notes, id)
    if (!note) return
    root.editorIsNew = false
    root.editingId = note.id
    root.draftTitle = note.title
    root.draftBody = note.body
    root.draftColor = note.color
    root.hoveredId = ""
    root.plusHovered = false
    root.editorOpen = true
    Qt.callLater(function() {
      editorCard.setDraft(note.title, note.body)
      editorCard.takeFocus()
    })
  }

  function closeEditor() {
    root.editorOpen = false
    root.editingId = ""
    root.draftTitle = ""
    root.draftBody = ""
  }

  function saveDraft(title, body, colorId) {
    var trimmedTitle = String(title || "")
    var trimmedBody = String(body || "")
    if (!trimmedTitle.trim() && !trimmedBody.trim()) {
      root.closeEditor()
      return
    }
    var color = colorId || root.draftColor
    var note
    if (root.editorIsNew) {
      note = NotesModel.newNote(trimmedTitle, trimmedBody, color)
    } else {
      note = NotesModel.findNote(root.notes, root.editingId)
      if (!note) note = NotesModel.newNote(trimmedTitle, trimmedBody, color)
      else {
        note = {
          id: note.id,
          title: trimmedTitle,
          body: trimmedBody,
          color: color,
          created: note.created,
          updated: Date.now()
        }
      }
    }
    root.setNotes(NotesModel.upsertNote(root.notes, note))
    root.persist()
    root.closeEditor()
  }

  function setNoteColor(id, colorId) {
    var note = NotesModel.findNote(root.notes, id)
    if (!note) return
    root.setNotes(NotesModel.upsertNote(root.notes, {
      id: note.id,
      title: note.title,
      body: note.body,
      color: colorId,
      created: note.created,
      updated: Date.now()
    }))
    root.persist()
    if (root.editingId === id) root.draftColor = colorId
  }

  function deleteNote(id) {
    root.setNotes(NotesModel.removeNote(root.notes, id))
    root.persist()
    if (root.editingId === id) root.closeEditor()
  }

  function deleteEditing() {
    if (root.editingId) root.deleteNote(root.editingId)
    else root.closeEditor()
  }

  function pickDraftColor(id) {
    root.draftColor = id
    if (!root.editorIsNew && root.editingId)
      root.setNoteColor(root.editingId, id)
  }

  function persist() {
    notesFile.setText(NotesModel.serialize({ edge: root.edge, notes: root.notes }))
  }

  function loadState(raw) {
    var state = NotesModel.parse(raw)
    var needsSeed = !state.seeded && state.notes.length === 0
    if (needsSeed) state = NotesModel.seedState()
    root.edge = state.edge
    root.setNotes(state.notes)
    if (needsSeed) root.persist()
  }

  function setNotes(list) {
    var next = []
    var src = list || []
    for (var i = 0; i < src.length; i++) next.push(src[i])
    root.notes = next
    root.notesRev = root.notesRev + 1
  }

  function layoutFor(available) {
    return NotesModel.packTabs(root.notes, available, {
      plusHeight: root.plusHeight,
      overlap: Style.space(10),
      minStep: Style.space(18),
      fontPx: Style.font.body,
      padding: Style.space(12),
      minHeight: Style.space(120),
      maxHeight: Style.space(240),
      bottomOffset: Style.space(100)
    })
  }

  function noteAt(index) {
    if (index < 0 || index >= root.notes.length) return null
    return root.notes[index]
  }

  Component.onCompleted: {
    mkdirProc.running = true
  }

  Process {
    id: mkdirProc
    command: ["bash", "-c", "mkdir -p \"$HOME/.local/state/omarchy\" && if [ ! -f \"$HOME/.local/state/omarchy/omatabs.json\" ] && [ -f \"$HOME/.local/state/omarchy/edge-notes.json\" ]; then cp \"$HOME/.local/state/omarchy/edge-notes.json\" \"$HOME/.local/state/omarchy/omatabs.json\"; fi"]
    onExited: notesFile.reload()
  }

  FileView {
    id: notesFile
    path: root.notesPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadState(text())
    onLoadFailed: root.loadState("")
    onFileChanged: reload()
  }

  IpcHandler {
    target: "tony.omatabs"
    function ping(): string { return "ok" }
    function newNote(): string { root.startNew(); return "ok" }
    function edge(side: string): string {
      if (side === "left" || side === "right") {
        root.edge = side
        root.persist()
      }
      return root.edge
    }
  }

  PanelWindow {
    id: strip
    visible: true
    color: "transparent"
    // Keep the Wayland surface at card size so hover never resizes the layer.
    implicitWidth: root.cardWidth
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "omarchy-omatabs"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors {
      top: true
      bottom: true
      right: root.onRight
      left: !root.onRight
    }
    mask: Region { item: stack }

    Item {
      id: stack
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.right: root.onRight ? parent.right : undefined
      anchors.left: root.onRight ? undefined : parent.left
      anchors.topMargin: Style.gapsOut + Style.space(28)
      anchors.bottomMargin: Style.gapsOut
      width: root.dockWidth
      Behavior on width {
        NumberAnimation {
          duration: root.hoveredId !== "" ? 120 : 80
          easing.type: Easing.OutCubic
        }
      }

      readonly property var pack: {
        var _rev = root.notesRev
        return root.layoutFor(height)
      }

      Item {
        id: plusTab
        z: 1000
        width: root.plusHeight + root.hang
        height: root.plusHeight
        y: stack.pack.plusY
        anchors.right: root.onRight ? parent.right : undefined
        anchors.left: root.onRight ? undefined : parent.left
        anchors.rightMargin: root.onRight ? -root.hang : 0
        anchors.leftMargin: root.onRight ? 0 : -root.hang

        BorderSurface {
          anchors.fill: parent
          color: root.paper
          borderSpec: root.paperBorder
          radius: Style.cornerRadius
          antialiasing: true
        }

        Text {
          anchors.centerIn: parent
          anchors.horizontalCenterOffset: root.onRight ? -root.hang / 2 : root.hang / 2
          text: "+"
          color: root.ink
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.startNew()
        }
      }

      Repeater {
        model: root.notesRev >= 0 ? root.notes.length : 0
        delegate: NoteTab {
          required property int index
          readonly property var note: {
            var _rev = root.notesRev
            return root.noteAt(index)
          }
          readonly property var slot: {
            var _rev = root.notesRev
            var items = stack.pack.items
            return (items && items[index]) ? items[index] : { y: 0, height: Style.space(72) }
          }
          readonly property string noteId: note ? note.id : ""
          y: slot.y
          height: slot.height
          z: index
          tilt: {
            var tilts = [2.4, 1.8, 2.8, 2.1, 1.6, 2.6]
            return tilts[index % tilts.length]
          }
          anchors.right: root.onRight ? parent.right : undefined
          anchors.left: root.onRight ? undefined : parent.left
          anchors.rightMargin: root.onRight ? -root.hang : 0
          anchors.leftMargin: root.onRight ? 0 : -root.hang
          onRight: root.onRight
          hang: root.hang
          hovered: !root.editorOpen && root.hoveredId === noteId
          editing: root.editorOpen && !root.editorIsNew && root.editingId === noteId
          title: note ? NotesModel.displayTitle(note) : "Untitled"
          body: note ? String(note.body || "") : ""
          colorId: note && note.color ? note.color : "yellow"
          spineWidth: root.spineWidth
          peekWidth: root.peekWidth
          onClicked: if (noteId) root.editNote(noteId)
          onColorPicked: function(id) { if (noteId) root.setNoteColor(noteId, id) }
          onDeleteClicked: if (noteId) root.deleteNote(noteId)
          onHoverChanged: function(isHovered) {
            if (root.editorOpen) return
            if (isHovered) {
              collapseTimer.stop()
              root.hoveredId = noteId
              root.plusHovered = false
            } else if (root.hoveredId === noteId) {
              collapseTimer.restart()
            }
          }
        }
      }

      Timer {
        id: collapseTimer
        interval: 20
        repeat: false
        onTriggered: {
          if (root.editorOpen) return
          root.hoveredId = ""
          root.plusHovered = false
        }
      }
    }
  }

  PanelWindow {
    id: stage
    visible: root.editorOpen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    implicitWidth: screen && screen.width > 0 ? screen.width : 1920
    implicitHeight: screen && screen.height > 0 ? screen.height : 1080
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "omarchy-omatabs-editor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.editorOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: editorCard }

    EditorCard {
      id: editorCard
      width: root.cardWidth
      height: root.cardHeight
      anchors.centerIn: parent
      hang: 0
      onRight: true
      isNew: root.editorIsNew
      colorId: root.draftColor
      onSaveRequested: function(title, body, colorId) { root.saveDraft(title, body, colorId) }
      onCancelRequested: root.closeEditor()
      onDeleteRequested: root.deleteEditing()
      onColorPicked: function(id) { root.pickDraftColor(id) }
    }
  }
}
